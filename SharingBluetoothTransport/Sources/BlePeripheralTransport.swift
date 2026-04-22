import CoreBluetooth
import Foundation

public protocol BlePeripheralTransportProtocol: AnyObject {
    var delegate: BluetoothTransportDelegate? { get set }
    func peripheralManagerState() -> CBManagerState
    func startAdvertising()
    func endSession()
    func sendData(_ data: Data)
}

public final class BlePeripheralTransport: NSObject, BlePeripheralTransportProtocol {
    public weak var delegate: BluetoothTransportDelegate?

    private(set) var subscribedCentral: BluetoothCentralProtocol?
    private(set) var characteristicData: [CharacteristicType: Data] = [:]
    private(set) var serviceCBUUID: CBUUID

    private var peripheralManager: PeripheralManagerProtocol
    
    private var connectionEstablished: Bool = false

    private var service: CBMutableService?

    init(
        peripheralManager: PeripheralManagerProtocol,
        serviceUUID: UUID,
    ) {
        self.peripheralManager = peripheralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.peripheralManager.delegate = self
    }

    public convenience init(serviceUUID: UUID) {
        self.init(
            peripheralManager: CBPeripheralManager(
                delegate: nil,
                queue: nil,
                options: [
                    CBPeripheralManagerOptionShowPowerAlertKey: false
                ]
            ),
            serviceUUID: serviceUUID
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
    
    func sendData(_ data: Data) {
        guard connectionEstablished,
              let serverToClientChar = service?.characteristics?.first(where: {
                  $0.uuid == CharacteristicType.serverToClient.uuid
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
        print("Calculated chunk size: \(maximumUpdateValueLength)")
        
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
                onError(.clientToServerError("Failed to send SessionData via serverToClient characteristic."))
                return
            }
            
            print("Payload of data with 0x01 header sent: \(payload)")
            
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
            onError(.clientToServerError("Failed to send SessionData via serverToClient characteristic."))
            return
        }
        
        print("Final payload of data with 0x00 header sent: \(payload)")
    }
    
    func stopAdvertising() {
        service = nil
        connectionEstablished = false
        peripheralManager.removeAllServices()
        peripheralManager.stopAdvertising()
    }

    func endSession() {
        if connectionEstablished,
           let stateChar = service?.characteristics?.first(where: {
               $0.uuid == CharacteristicType.state.uuid
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
            print("GATT Notified 'State' characteristic with: \([UInt8](ConnectionState.end.data))")
            print("BLE session terminated successfully via GATT End command")
            if !sent {
                print("Failed to notify GATT end command")
                onError(.failedToNotifyEnd)
            }
        }
        stopAdvertising()
    }

    internal func onError(_ error: PeripheralError) {
        delegate?.bluetoothTransportDidFail(with: error)
        print(error.errorDescription ?? "")
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
        print("PeripheralManager did add service: \(service) for peripheral: \(peripheral)")
    }
    
    func handleDidStartAdvertising(
        for peripheral: any PeripheralManagerProtocol,
        error: (any Error)?
    ) {
        if let error {
            onError(.startAdvertisingError(error.localizedDescription))
        } else {
            print("Advertising started: ", peripheral.isAdvertising)
            delegate?.bluetoothTransportDidStartAdvertising()
        }
    }

    func handleDidSubscribe(
        for peripheral: any PeripheralManagerProtocol,
        central: any BluetoothCentralProtocol,
        to characteristic: CBCharacteristic
    ) {
        
        if subscribedCentral == nil {
            self.subscribedCentral = central
        } else if subscribedCentral?.identifier != central.identifier {
            onError(.centralSubscriptionError("A different Central has already subscribed"))
            return
        }

        print("Central: \(central) did subscribe to characteristic: \(characteristic), for peripheral: \(peripheral).")
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
        case CharacteristicType.state.uuid:
            handleStateRequest(for: peripheral, with: firstRequest)
        case CharacteristicType.clientToServer.uuid:
            handleClientToServerRequest(from: firstRequest.value)
        default:
            return
        }
    }
    
    private func handleStateRequest(for peripheral: any PeripheralManagerProtocol, with request: any ATTRequestProtocol) {
        if request.value == ConnectionState.start.data {
            print("Start request received")
            peripheral.respond(to: request, withResult: .success)
            // connection started
            connectionEstablished = true
        } else if request.value == ConnectionState.end.data {
            print("GATT received write request 0x02 on State")
            peripheral.respond(to: request, withResult: .success)
            connectionEstablished = false
            delegate?.bluetoothTransportDidReceiveMessageEndRequest()
        } else {
            peripheral
                .respond(to: request, withResult: .requestNotSupported)
        }
    }
    
    func handleDidUnsubscribe() {
        onError(.connectionTerminated)
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
            characteristicData[.clientToServer] = previousMessages + newMessage
            print(
                "Partial message received, further messages expected."
            )
        case MessageDataFirstByte.endOfData.rawValue:
            characteristicData[.clientToServer] = previousMessages + newMessage
            print(
                "Full message received: \(characteristicData[.clientToServer]?.base64EncodedString() ?? "")"
            )
            delegate?.bluetoothTransportDidReceiveMessageData(
                previousMessages + newMessage
            )
            characteristicData[.clientToServer] = nil
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
