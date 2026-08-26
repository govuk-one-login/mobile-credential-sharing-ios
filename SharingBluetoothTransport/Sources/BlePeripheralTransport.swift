import CoreBluetooth
import Foundation
import SharingLogging

public protocol BlePeripheralTransportProtocol: AnyObject {
    var delegate: BluetoothTransportDelegate? { get set }
    func peripheralManagerState() -> CBManagerState
    func startAdvertising()
    func endSession(andNotify: Bool)
    func send(_ data: Data)
}

public final class BlePeripheralTransport: NSObject, BlePeripheralTransportProtocol {
    public static let defaultMaxReceiveBufferSize = 64 * 1024
    
    public weak var delegate: BluetoothTransportDelegate?

    private(set) var subscribedCentral: BluetoothCentralProtocol?
    private(set) var characteristicData: [CharacteristicType: Data] = [:]
    private(set) var serviceCBUUID: CBUUID

    private var peripheralManager: PeripheralManagerProtocol
    
    let maxReceiveBufferSize: Int
    
    private var connectionEstablished: Bool = false

    private var service: CBMutableService?
    
    var pendingData: Data?

    init(
        peripheralManager: PeripheralManagerProtocol,
        serviceUUID: UUID,
        maxReceiveBufferSize: Int = defaultMaxReceiveBufferSize
    ) {
        self.peripheralManager = peripheralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        self.maxReceiveBufferSize = maxReceiveBufferSize
        super.init()
        self.peripheralManager.delegate = self
    }

    public convenience init(
        serviceUUID: UUID,
        maxReceiveBufferSize: Int = defaultMaxReceiveBufferSize
    ) {
        self.init(
            peripheralManager: CBPeripheralManager(
                delegate: nil,
                queue: nil,
                options: [
                    CBPeripheralManagerOptionShowPowerAlertKey: false
                ]
            ),
            serviceUUID: serviceUUID,
            maxReceiveBufferSize: maxReceiveBufferSize
        )
    }

    deinit {
        self.stopAdvertising()
    }
}

public extension BlePeripheralTransport {
    func peripheralManagerState() -> CBManagerState {
        return peripheralManager.state
    }

    func startAdvertising() {
        let service = self.mutableServiceWithServiceCharacterics(self.serviceCBUUID)
        self.service = service
        peripheralManager.removeAllServices()
        peripheralManager.add(service)
        peripheralManager.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
        )
    }
    
    func send(_ data: Data) {
        guard connectionEstablished,
              let serverToClientChar = service?.characteristics?.first(where: {
                  $0.uuid == CharacteristicType.serverToClient.cbUUID
              }) as? CBMutableCharacteristic else {
            onError(.clientToServerError("Cannot send data: connection not established or characteristic unavailable."))
            return
        }
        
        guard let subscribedCentral = subscribedCentral else {
            onError(.centralSubscriptionError("subscribedCentral should not be nil"))
            return
        }
        
        // Get the Maximum Transmission Unit from the subscribed Central, subtract 1 byte to allow for first byte value
        /// The `subscribedCentral.maximumUpdateValueLength` from CoreBluetooth already subtracts the 3 BLE overhead bytes
        let maximumUpdateValueLength: Int = (subscribedCentral.maximumUpdateValueLength - 1)
        OSLoggingService.shared.logEvent(LoggingEvents.calculatedChunkSize, parameters: ["chunk size": maximumUpdateValueLength])
        
        var dataToSend = data
        
        // While the data to send is greater than the maximum length, we must send only a prefix up to that number, appended with the `moreData` first byte
        while dataToSend.count > maximumUpdateValueLength {
            let payload = Data([MessageDataFirstByte.moreData.rawValue]) + dataToSend.prefix(maximumUpdateValueLength)
            let sent = peripheralManager.updateValue(
                payload,
                for: serverToClientChar,
                onSubscribedCentrals: [subscribedCentral]
            )
            if !sent {
                self.pendingData = dataToSend
                return
            }
            
            OSLoggingService.shared.logEvent(LoggingEvents.payloadOfDataWithHeader, parameters: ["payload": payload])
            
            // Subtract the sent data from our `dataToSend` object
            dataToSend = dataToSend.dropFirst(maximumUpdateValueLength)
        }
        
        // Once the `dataToSend` is less than or equal to the maximum length, we send the full remaining data, appended with the `endOfData` first byte
        let payload = Data([MessageDataFirstByte.endOfData.rawValue]) + dataToSend
        let sent = peripheralManager.updateValue(
            payload,
            for: serverToClientChar,
            onSubscribedCentrals: [subscribedCentral]
        )
        if !sent {
            self.pendingData = dataToSend
            return
        }
        
        OSLoggingService.shared.logEvent(LoggingEvents.finalPayloadOfData, parameters: ["payload": payload])
        delegate?.bluetoothTransportDidFinishSending()
    }
    
    func stopAdvertising() {
        service = nil
        connectionEstablished = false
        peripheralManager.removeAllServices()
        peripheralManager.stopAdvertising()
    }

    func endSession(andNotify: Bool) {
        if connectionEstablished && andNotify,
           let stateChar = service?.characteristics?.first(where: {
               $0.uuid == CharacteristicType.state.cbUUID
           }) as? CBMutableCharacteristic {
            stateChar.value = ConnectionState.end.data
            guard let subscribedCentral = subscribedCentral else {
                onError(.centralSubscriptionError("subscribedCentral should not be nil"))
                return
            }
            let sent = peripheralManager.updateValue(
                ConnectionState.end.data,
                for: stateChar,
                onSubscribedCentrals: [subscribedCentral]
            )
            OSLoggingService.shared.logEvent(LoggingEvents.gattNotifiedStateCharacteristics,
                                             parameters: ["data": ConnectionState.end.data])
            OSLoggingService.shared.logEvent(LoggingEvents.bleSessionTerminatedGattEnd)
            if !sent {
                OSLoggingService.shared.logEvent(LoggingEvents.failedToNotifyGattEnd)
                onError(.failedToNotifyEnd)
            }
        }
        stopAdvertising()
    }

    internal func onError(_ error: PeripheralError) {
        delegate?.bluetoothTransportDidFail(with: .peripheral(error))
        OSLoggingService.shared.logEvent(LoggingEvents.failedWithError,
                                         parameters: ["error": error.errorDescription ?? ""])
    }

    internal func mutableServiceWithServiceCharacterics(_ cbUUID: CBUUID) -> CBMutableService {
        let characteristics: [CBMutableCharacteristic] = CharacteristicType
            .allCases.compactMap(
                { CBMutableCharacteristic(characteristic: $0) }
            )

        let service = CBMutableService(type: cbUUID, primary: true)
        service.characteristics = characteristics
        service.includedServices = []

        return service
    }
}

extension BlePeripheralTransport {
    func handleDidUpdateState(for peripheral: any PeripheralManagerProtocol) {
        let authorization = peripheral.authorization
        switch authorization {
        case .allowedAlways:
            switch peripheral.state {
            case .poweredOn:
                delegate?.bluetoothTransportDidPowerOn()
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                onError(.notPoweredOn(peripheral.state))
            @unknown default:
                onError(.unknown)
            }
        case .notDetermined, .restricted, .denied:
            onError(.permissionsNotGranted(authorization))
        @unknown default:
            onError(.unknown)
        }
    }

    func handleDidAddService(
        for peripheral: any PeripheralManagerProtocol,
        service: CBService,
        error: (any Error)?
    ) {
        if let error {
            let peripheralError = PeripheralError.addServiceError(error.localizedDescription)

            // Notify delegate of failure
            onError(peripheralError)
            return
        }
        OSLoggingService.shared.logEvent(LoggingEvents.peripheralDidAddService,
                                         parameters: ["service": service, "periphereal": peripheral])
    }
    
    func handleDidStartAdvertising(
        for peripheral: any PeripheralManagerProtocol,
        error: (any Error)?
    ) {
        if let error {
            onError(.startAdvertisingError(error.localizedDescription))
        } else {
            OSLoggingService.shared.logEvent(LoggingEvents.advertisingStarted,
                                             parameters: ["isAdvertising": peripheral.isAdvertising])
            delegate?.bluetoothTransportDidStartAdvertising()
        }
    }

    func handleDidSubscribe(
        for peripheral: any PeripheralManagerProtocol,
        central: any BluetoothCentralProtocol,
        to _: CBCharacteristic
    ) {
        
        if subscribedCentral == nil {
            self.subscribedCentral = central
        } else if subscribedCentral?.identifier != central.identifier {
            onError(.centralSubscriptionError("A different Central has already subscribed"))
            return
        }

        OSLoggingService.shared.logEvent(LoggingEvents.centralDidSubscribeCharactertic,
                                         parameters: ["central": central, "peripheral": peripheral])
        // Check if both chars have been subscribed to before forwarding to delegate?
        delegate?.bluetoothTransportConnectionDidConnect()
    }

    func handleDidReceiveWrite(
        for peripheral: any PeripheralManagerProtocol,
        with requests: [any ATTRequestProtocol]
    ) {
        guard let firstRequest = requests.first else {
            return
        }

        switch firstRequest.characteristic.uuid {
        case CharacteristicType.state.cbUUID:
            handleStateRequest(for: peripheral, with: firstRequest)
        case CharacteristicType.clientToServer.cbUUID:
            handleClientToServerRequest(from: firstRequest.value)
        default:
            return
        }
    }
    
    private func handleStateRequest(for peripheral: any PeripheralManagerProtocol, with request: any ATTRequestProtocol) {
        if request.value == ConnectionState.start.data {
            OSLoggingService.shared.logEvent(LoggingEvents.startRequestReceived)
            peripheral.respond(to: request, withResult: .success)
            // connection started
            connectionEstablished = true
        } else if request.value == ConnectionState.end.data {
            OSLoggingService.shared.logEvent(LoggingEvents.gattEndReceivedWriteRequest)
            peripheral.respond(to: request, withResult: .success)
            connectionEstablished = false
            delegate?.bluetoothTransportDidReceiveMessageEndRequest()
        } else {
            peripheral
                .respond(to: request, withResult: .requestNotSupported)
        }
    }
    
    func handleDidUnsubscribe() {
        guard connectionEstablished else { return }
        delegate?.bluetoothTransportDidFail(with: .peripheral(.connectionTerminated))
    }
    
    func handleManagerIsReady() {
        guard let pendingData = self.pendingData else { return }
        self.pendingData = nil
        send(pendingData)
    }
    
    private func handleClientToServerRequest(from data: Data?) {
        guard connectionEstablished else {
            onError(.clientToServerError("Connection not established."))
            return
        }
        
        guard let data else {
            onError(.clientToServerError("Invalid data received, data is nil."))
            return
        }
        
        let bytes = [UInt8](data)
        guard let firstByte = bytes.first else {
            onError(.clientToServerError("Invalid data received, empty byte array."))
            return
        }
        
        let previousMessages = characteristicData[.clientToServer] ?? Data()
        let newMessage = Data(bytes.dropFirst())
        
        switch firstByte {
        case MessageDataFirstByte.moreData.rawValue:
            let accumulated = previousMessages + newMessage
            if accumulated.count > maxReceiveBufferSize {
                characteristicData[.clientToServer] = nil
                onError(.exceededMaxBufferSize(currentSize: accumulated.count, maxSize: maxReceiveBufferSize))
                endSession(andNotify: true)
            } else {
                characteristicData[.clientToServer] = accumulated
                    OSLoggingService.shared.logEvent(LoggingEvents.partialMessageWithFurtherBytesExpected,
                                                     parameters: ["count": accumulated.count, "bytes": maxReceiveBufferSize])
            }
        case MessageDataFirstByte.endOfData.rawValue:
            let fullMessage = previousMessages + newMessage
            
            if fullMessage.count > maxReceiveBufferSize {
                characteristicData[.clientToServer] = nil
                onError(.exceededMaxBufferSize(currentSize: fullMessage.count, maxSize: maxReceiveBufferSize))
                endSession(andNotify: true)
                return
            }
            
            characteristicData[.clientToServer] = nil
            OSLoggingService.shared.logEvent(LoggingEvents.fullBytesReceived, parameters: ["count": fullMessage.count, "bufferSize": fullMessage.base64EncodedString()])
            delegate?.bluetoothTransportDidReceiveMessageData(fullMessage)
        default:
            onError(
                .clientToServerError(
                    "Invalid data received, first byte was not 0x01 or 0x00."
                )
            )
            return
        }
    }
}

enum ConnectionState: UInt8 {
    case start = 0x01
    case end = 0x02

    var data: Data {
        Data([rawValue])
    }
}

enum MessageDataFirstByte: UInt8 {
    case moreData = 0x01
    case endOfData = 0x00
}
