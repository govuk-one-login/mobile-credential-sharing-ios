import CoreBluetooth
import Foundation

public protocol BleCentralTransportDelegate: AnyObject {
    func bleCentralTransportDidPowerOn()
    func bleCentralTransportDidDiscoverPeripheral()
    func bleCentralTransportDidConnect()
    func bleCentralTransportDidDiscoverServices()
    func bleCentralTransportDidDiscoverCharacteristics(for service: CBService)
    func bleCentralTransportDidReceiveMessageData(_ messageData: Data)
    func bleCentralTransportDidFail(with error: CentralError)
}

public protocol BleCentralTransportProtocol: AnyObject {
    var delegate: BleCentralTransportDelegate? { get set }
    func startScanning()
    func stopScanning()
    func connect()
    func discoverServices()
    func discoverCharacteristics()
    func startTransport() throws
    func endSession()
}

public final class BleCentralTransport: NSObject, BleCentralTransportProtocol {
    public weak var delegate: BleCentralTransportDelegate?
    private(set) var serviceCBUUID: CBUUID
    private(set) var peripheral: BluetoothPeripheralProtocol?
    private(set) var gattService: CBService?
    private var centralManager: CentralManagerProtocol
    private(set) var stateSubscribed = false
    private(set) var serverToClientSubscribed = false
    
    private(set) var characteristicData: [CharacteristicType: Data] = [:]

    init(
        centralManager: CentralManagerProtocol,
        serviceUUID: UUID
    ) {
        self.centralManager = centralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.centralManager.delegate = self
    }

    public convenience init(serviceUUID: UUID) {
        self.init(
            centralManager: CBCentralManager(
                delegate: nil,
                queue: nil
            ),
            serviceUUID: serviceUUID
        )
    }
    
    internal func onError(_ error: CentralError) {
        delegate?.bleCentralTransportDidFail(with: error)
        print(error.errorDescription ?? "")
    }

    deinit {
        stopScanning()
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
        print("Scanning started for service UUID: \(serviceCBUUID)")
    }

    func stopScanning() {
        guard centralManager.isScanning else { return }
        centralManager.stopScan()
        print("Scanning stopped.")
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
    
    func startTransport() throws {
        guard let gattService else {
            throw CentralError.gattServiceMissing
        }
        
        guard let peripheral else {
            throw CentralError.discoverServicesError("GATT Service peripheral not stored.")
        }
        
        guard let stateCharacteristic = gattService.characteristics?.first(where: { $0.uuid == CharacteristicType.state.cbUUID }) else {
            throw CentralError.discoverCharacteristicsError("State characteristic is missing from GATT Service.")
        }
        
        guard let serverToClientCharacteristic = gattService.characteristics?.first(where: { $0.uuid == CharacteristicType.serverToClient.cbUUID }) else {
            throw CentralError.discoverCharacteristicsError("Server2Client characteristic is missing from GATT Service.")
        }
        
        stateSubscribed = false
        serverToClientSubscribed = false
        peripheral.setNotifyValue(true, for: stateCharacteristic)
        peripheral.setNotifyValue(true, for: serverToClientCharacteristic)
    }
    
    private func writeStart() {
        guard let gattService,
              let peripheral,
              let stateCharacteristic = gattService.characteristics?.first(where: { $0.uuid == CharacteristicType.state.cbUUID }) else {
            print("Failed to write 'Start' state")
            onError(.transportError("Failed to write 'Start' state"))
            endSession()
            return
        }
        
        guard peripheral.canSendWriteWithoutResponse else {
            print("Failed to write 'Start' state")
            onError(.transportError("Failed to write 'Start' state"))
            endSession()
            return
        }
        
        let negotiatedMTU = peripheral.maximumWriteValueLength(for: .withoutResponse)
        print("MTU negotiated: \(negotiatedMTU).")
        
        peripheral.writeValue(
            ConnectionState.start.data,
            for: stateCharacteristic,
            type: .withoutResponse
        )
        print("Session is now active, ready to send a request.")
    }
    
    func endSession() {
        guard let peripheral else {
            onError(.connectError)
            return
        }
        
        // TODO: DCMAW-18132 Update endSession logic to send END on State etc.
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate handle funcs
extension BleCentralTransport {
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
        print("Discovered peripheral advertising service UUID: \(serviceCBUUID.uuidString)")
        delegate?.bleCentralTransportDidDiscoverPeripheral()
    }
    
    func handleDidConnect(
        _ peripheral: any BluetoothPeripheralProtocol
    ) {
        print("Successfully connected to peripheral: \(peripheral.name ?? "unknown name"), \(peripheral.identifier)")
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
            print("Failed to subscribe to characteristics")
            onError(.transportError("Failed to subscribe to characteristics"))
            endSession()
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
            print("Subscribed to session characteristics.")
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
            // This is the response data from the peripheral (holder)
            // Process the received data chunk
            print("Received \(data.count) bytes from peripheral")
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
                characteristicData[.serverToClient] = previousMessages + newMessage
                print("Partial message received, further messages expected.")
            case MessageDataFirstByte.endOfData.rawValue:
                let completeMessage = previousMessages + newMessage
                characteristicData[.serverToClient] = nil
                print("Full message received, \(completeMessage.count) bytes.")
                delegate?.bleCentralTransportDidReceiveMessageData(completeMessage)
            default:
                characteristicData[.serverToClient] = nil
                onError(.serverToClientError("Invalid data received, first byte was not 0x01 or 0x00."))
                return
            }
        case CharacteristicType.state.cbUUID:
            // State change notification from peripheral
            print("State update received")
        default:
            break
        }
    }
}
