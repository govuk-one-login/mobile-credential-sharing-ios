import CoreBluetooth
import Foundation
import SharingLogging

// swiftlint:disable file_length
public protocol BleCentralTransportDelegate: AnyObject {
    func bleCentralTransportDidPowerOn()
    func bleCentralTransportDidDiscoverPeripheral()
    func bleCentralTransportDidConnect()
    func bleCentralTransportDidDiscoverServices()
    func bleCentralTransportDidDiscoverCharacteristics(for service: CBService)
    func bleCentralTransportDidStartSession()
    func bleCentralTransportDidReceiveMessageData(_ messageData: Data)
    func bleCentralTransportDidReceiveMessageEndRequest()
    func bleCentralTransportDidFinishSending()
    func bleCentralTransportDidFail(with error: CentralError)
}

public protocol BleCentralTransportProtocol: AnyObject {
    var delegate: BleCentralTransportDelegate? { get set }
    var isConnected: Bool { get }
    func startScanning()
    func stopScanning()
    func connect()
    func discoverServices()
    func discoverCharacteristics()
    func startTransport()
    func send(_ data: Data)
    func endSession(andNotify: Bool)
}

public final class BleCentralTransport: NSObject, BleCentralTransportProtocol {
    /// Default maximum receive buffer size: 2MB
    public static let defaultMaxReceiveBufferSize: Int = 2 * 1024 * 1024
    
    public weak var delegate: BleCentralTransportDelegate?
    private(set) var serviceCBUUID: CBUUID
    private(set) var peripheral: BluetoothPeripheralProtocol?
    private(set) var gattService: CBService?
    private var centralManager: CentralManagerProtocol
    private(set) var stateSubscribed = false
    private(set) var serverToClientSubscribed = false
    
    /// The maximum number of bytes the receive buffer is allowed to accumulate
    /// before the session is terminated. Defaults to 2MB.
    let maxReceiveBufferSize: Int
    
    public var isConnected: Bool {
        peripheral?.state == .connected
    }
    
    private var connectionEstablished: Bool = false
    
    private(set) var characteristicData: [CharacteristicType: Data] = [:]
    private var stateCharacteristic: CBCharacteristic?

    var pendingData: Data?

    init(
        centralManager: CentralManagerProtocol,
        serviceUUID: UUID,
        maxReceiveBufferSize: Int = defaultMaxReceiveBufferSize
    ) {
        self.centralManager = centralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        self.maxReceiveBufferSize = maxReceiveBufferSize
        super.init()
        self.centralManager.delegate = self
    }

    public convenience init(
        serviceUUID: UUID,
        maxReceiveBufferSize: Int = defaultMaxReceiveBufferSize
    ) {
        self.init(
            centralManager: CBCentralManager(
                delegate: nil,
                queue: nil
            ),
            serviceUUID: serviceUUID,
            maxReceiveBufferSize: maxReceiveBufferSize
        )
    }
    
    internal func onError(_ error: CentralError) {
        delegate?.bleCentralTransportDidFail(with: error)
        OSLoggingService.shared.logEvent(LoggingEvents.failedWithError, parameters: ["error": error])
    }

    deinit {
        stopScanning()
        connectionEstablished = false
    }
}

// MARK: - Public funcs
public extension BleCentralTransport {
    func startScanning() {
        guard centralManager.state == .poweredOn,
              !centralManager.isScanning else {
            return
        }

        centralManager.scanForPeripherals(
            withServices: [serviceCBUUID],
            options: nil
        )
        OSLoggingService.shared.logEvent(LoggingEvents.scanningStartedForUUID,
                                         parameters: ["UUID": serviceCBUUID])
    }

    func stopScanning() {
        guard centralManager.isScanning else { return }
        centralManager.stopScan()
        OSLoggingService.shared.logEvent(LoggingEvents.scanningStopped)
    }
    
    func connect() {
        guard let peripheral else {
            onError(.connectError)
            return
        }
        centralManager.connect(peripheral, options: nil)
    }
    
    func discoverServices() {
        self.peripheral?.delegate = self
        self.peripheral?.discoverServices([serviceCBUUID])
    }
    
    func discoverCharacteristics() {
        guard let peripheral = self.peripheral,
              let service = peripheral.services?.first(where: {
                  $0.uuid == serviceCBUUID
              }) else {
            onError(.discoverServicesError("mDL GATT service not found"))
            return
        }
        let mdlGATTCharacteristics: [CBUUID] = CharacteristicType.allCases.map { $0.cbUUID }
        peripheral.discoverCharacteristics(mdlGATTCharacteristics, for: service)
    }
    
    func startTransport() {
        guard let gattService else {
            onError(.gattServiceMissing)
            return
        }
        
        guard let peripheral else {
            onError(.discoverServicesError("GATT Service peripheral not stored."))
            return
        }
        
        guard let stateCharacteristic = gattService.characteristics?.first(where: { $0.uuid == CharacteristicType.state.cbUUID }) else {
            onError(.discoverCharacteristicsError("State characteristic is missing from GATT Service."))
            return
        }
        self.stateCharacteristic = stateCharacteristic
        
        guard let serverToClientCharacteristic = gattService.characteristics?.first(where: { $0.uuid == CharacteristicType.serverToClient.cbUUID }) else {
            onError(.discoverCharacteristicsError("Server2Client characteristic is missing from GATT Service."))
            return
        }
        
        stateSubscribed = false
        serverToClientSubscribed = false
        peripheral.setNotifyValue(true, for: stateCharacteristic)
        peripheral.setNotifyValue(true, for: serverToClientCharacteristic)
    }
    
    private func writeStart() {
        guard let peripheral,
              let stateCharacteristic else {
            OSLoggingService.shared.logEvent(LoggingEvents.failedToWriteStartState)
            onError(.transportError("Failed to write 'Start' state"))
            endSession(andNotify: false)
            return
        }
        
        guard peripheral.canSendWriteWithoutResponse else {
            OSLoggingService.shared.logEvent(LoggingEvents.failedToWriteStartState)
            onError(.transportError("Failed to write 'Start' state"))
            endSession(andNotify: false)
            return
        }
        
        let negotiatedMTU = peripheral.maximumWriteValueLength(for: .withoutResponse)
        OSLoggingService.shared.logEvent(LoggingEvents.mtuNegotiated, parameters: ["MTU": negotiatedMTU])
        
        peripheral.writeValue(
            ConnectionState.start.data,
            for: stateCharacteristic,
            type: .withoutResponse
        )
        
        connectionEstablished = true
        OSLoggingService.shared.logEvent(LoggingEvents.sessionNowReady)
        delegate?.bleCentralTransportDidStartSession()
    }
    
    func send(_ data: Data) {
        guard connectionEstablished,
              let peripheral,
              let clientToServerChar = gattService?.characteristics?.first(where: {
                  $0.uuid == CharacteristicType.clientToServer.cbUUID
              }) else {
            onError(.clientToServerError("Cannot send data: connection not established or characteristic unavailable."))
            return
        }
        
        // Get the Maximum Transmission Unit from the peripheral, subtract 1 byte to allow for first byte value
        /// The `maximumWriteValueLength` from CoreBluetooth already subtracts the 3 BLE overhead bytes
        let maximumWriteValueLength: Int = peripheral.maximumWriteValueLength(for: .withoutResponse) - 1
        OSLoggingService.shared.logEvent(LoggingEvents.calculatedChunkSize,
                                         parameters: ["chunk size": maximumWriteValueLength])
        
        var dataToSend = data
        
        // While the data to send is greater than the maximum length, we must send only a prefix up to that number, appended with the `moreData` first byte
        while dataToSend.count > maximumWriteValueLength {
            guard peripheral.canSendWriteWithoutResponse else {
                self.pendingData = dataToSend
                return
            }
            
            let payload = Data([MessageDataFirstByte.moreData.rawValue]) + dataToSend.prefix(maximumWriteValueLength)
            peripheral.writeValue(
                payload,
                for: clientToServerChar,
                type: .withoutResponse
            )
            
            OSLoggingService.shared.logEvent(LoggingEvents.payloadOfDataWithHeader,
                                             parameters: ["payload": payload])
            
            // Subtract the sent data from our `dataToSend` object
            dataToSend = dataToSend.dropFirst(maximumWriteValueLength)
        }
        
        // Once the `dataToSend` is less than or equal to the maximum length, we send the full remaining data, appended with the `endOfData` first byte
        guard peripheral.canSendWriteWithoutResponse else {
            self.pendingData = dataToSend
            return
        }
        
        let payload = Data([MessageDataFirstByte.endOfData.rawValue]) + dataToSend
        peripheral.writeValue(
            payload,
            for: clientToServerChar,
            type: .withoutResponse
        )
        OSLoggingService.shared.logEvent(LoggingEvents.finalPayloadOfData,
                                         parameters: ["payload": payload])
        delegate?.bleCentralTransportDidFinishSending()
    }
    
    func endSession(andNotify: Bool) {
        guard let peripheral else {
            onError(.connectError)
            return
        }

        if connectionEstablished && andNotify,
           let stateCharacteristic {
            peripheral.writeValue(
                ConnectionState.end.data,
                for: stateCharacteristic,
                type: .withoutResponse
            )
            OSLoggingService.shared.logEvent(LoggingEvents.gattEndWritten,
                                             parameters: ["data": ConnectionState.end.data])
            OSLoggingService.shared.logEvent(LoggingEvents.bleSessionTerminatedGattEnd)
        }

        connectionEstablished = false
        stateCharacteristic = nil
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate handle funcs
extension BleCentralTransport {
    func handleDidDisconnect() {
        OSLoggingService.shared.logEvent(LoggingEvents.pheripheralDisconnected)
        connectionEstablished = false
        delegate?.bleCentralTransportDidFail(with: .connectionTerminated)
    }

    func handleDidUpdateState(for central: any CentralManagerProtocol) {
        let authorization = central.authorization
        switch authorization {
        case .allowedAlways:
            switch central.state {
            case .poweredOn:
                delegate?.bleCentralTransportDidPowerOn()
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                onError(.notPoweredOn(central.state))
            @unknown default:
                onError(.unknown)
            }
        case .notDetermined, .restricted, .denied:
            onError(.permissionsNotGranted(authorization))
        @unknown default:
            onError(.unknown)
        }
    }

    func handleDidDiscoverPeripheral(
        for peripheral: any BluetoothPeripheralProtocol
    ) {
        self.peripheral = peripheral
        OSLoggingService.shared.logEvent(LoggingEvents.discoveredPeripheralUUID,
                                         parameters: ["UUID": serviceCBUUID.uuidString])
        delegate?.bleCentralTransportDidDiscoverPeripheral()
    }
    
    func handleDidConnect(
        _ peripheral: any BluetoothPeripheralProtocol
    ) {
        OSLoggingService.shared.logEvent(LoggingEvents.successfullyConnectedToPeripheral,
                                         parameters: ["name": peripheral.name ?? "",
                                                      "identifier": peripheral.identifier])
        delegate?.bleCentralTransportDidConnect()
    }
}

// MARK: - CBPeripheralDelegate handle funcs
extension BleCentralTransport {
    func handleDidDiscoverServices(
        error: (any Error)?
    ) {
        if error != nil {
            onError(.discoverServicesError("mDL GATT service not found."))
        } else {
            delegate?.bleCentralTransportDidDiscoverServices()
        }
    }
    
    func handleDidDiscoverCharacteristics(
        for service: CBService,
        error: (any Error)?
    ) {
        if let error {
            onError(.discoverCharacteristicsError(error.localizedDescription))
        } else {
            gattService = service
            delegate?.bleCentralTransportDidDiscoverCharacteristics(for: service)
        }
    }
    
    func handleDidUpdateNotificationState(
        for characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        if error != nil {
            OSLoggingService.shared.logEvent(LoggingEvents.failedToSubscribe)
            onError(.transportError("Failed to subscribe to characteristics"))
            endSession(andNotify: false)
            return
        }
        
        switch characteristic.uuid {
        case CharacteristicType.state.cbUUID:
            stateSubscribed = true
        case CharacteristicType.serverToClient.cbUUID:
            serverToClientSubscribed = true
        default:
            break
        }
        
        if stateSubscribed && serverToClientSubscribed {
            OSLoggingService.shared.logEvent(LoggingEvents.subscribedToSession)
            writeStart()
        }
    }
    
    func handleDidUpdateValue(
        for characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil,
              let data = characteristic.value else {
            onError(.transportError("Failed to read characteristic value"))
            return
        }
          
        switch characteristic.uuid {
        case CharacteristicType.serverToClient.cbUUID:
            handleServerToClientData(data)
        case CharacteristicType.state.cbUUID:
            if data == ConnectionState.end.data {
                OSLoggingService.shared.logEvent(LoggingEvents.stateUpdateReceived)
                connectionEstablished = false
                delegate?.bleCentralTransportDidReceiveMessageEndRequest()
            }
        default:
            break
        }
    }
    
    private func handleServerToClientData(_ data: Data) {
        // This is the response data from the peripheral (holder)
        // Process the received data chunk
        OSLoggingService.shared.logEvent(LoggingEvents.receivedBytes, parameters: ["bytes": data.count])
        let bytes = [UInt8](data)
        guard let firstByte = bytes.first else {
            characteristicData[.serverToClient] = nil
            onError(.serverToClientError("Invalid data received, empty byte array."))
            return
        }
          
        let previousMessages = characteristicData[.serverToClient] ?? Data()
        let newMessage = Data(bytes.dropFirst())
          
        switch firstByte {
        case MessageDataFirstByte.moreData.rawValue:
            let accumulated = previousMessages + newMessage
            if accumulated.count > maxReceiveBufferSize {
                characteristicData[.serverToClient] = nil
                onError(.exceededMaxBufferSize(currentSize: accumulated.count, maxSize: maxReceiveBufferSize))
                endSession(andNotify: true)
                return
            }
            characteristicData[.serverToClient] = accumulated

            OSLoggingService.shared.logEvent(LoggingEvents.partialMessageWithFurtherBytesExpected,
                                             parameters: ["bytes": maxReceiveBufferSize])
        case MessageDataFirstByte.endOfData.rawValue:
            let completeMessage = previousMessages + newMessage
            if completeMessage.count > maxReceiveBufferSize {
                characteristicData[.serverToClient] = nil
                onError(.exceededMaxBufferSize(currentSize: completeMessage.count, maxSize: maxReceiveBufferSize))
                endSession(andNotify: true)
                return
            }
            characteristicData[.serverToClient] = nil
            OSLoggingService.shared.logEvent(LoggingEvents.fullBytesReceived, parameters: ["bytes": completeMessage.count])
            delegate?.bleCentralTransportDidReceiveMessageData(completeMessage)
        default:
            characteristicData[.serverToClient] = nil
            onError(.serverToClientError("Invalid data received, first byte was not 0x01 or 0x00."))
            return
        }
    }
    
    func handlePeripheralIsReady() {
        guard let pendingData = self.pendingData else { return }
        self.pendingData = nil
        send(pendingData)
    }
}
