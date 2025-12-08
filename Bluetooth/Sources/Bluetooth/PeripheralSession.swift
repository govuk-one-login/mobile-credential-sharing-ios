import CoreBluetooth
import Foundation

public final class PeripheralSession: NSObject {

    public weak var delegate: PeripheralSessionDelegate?
    
    private(set) var subscribedCentrals: [CBCharacteristic: [BluetoothCentralProtocol]] = [:]
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    private(set) var serviceCBUUID: CBUUID
    
    private var peripheralManager: PeripheralManagerProtocol
    
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
            peripheralManager: CBPeripheralManager(delegate: nil, queue: nil, options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]),
            serviceUUID: serviceUUID
        )
    }
    
    deinit {
        self.stopAdvertising()
    }
}

extension PeripheralSession {
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
    
    func handleStateChange(for peripheral: any PeripheralManagerProtocol) {
        let authorization: CBManagerAuthorization = type(
            of: peripheral
        ).authorization
        switch authorization {
        case .allowedAlways:
            switch peripheral.state {
            case .poweredOn:
                startAdvertising(peripheral)
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
    
    private func startAdvertising(_ peripheral: any PeripheralManagerProtocol) {
        let service = self.mutableServiceWithServiceCharacterics(self.serviceCBUUID)
        peripheral.removeAllServices()
        peripheral.add(service)
        peripheral.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
        )
    }
    
    func mutableServiceWithServiceCharacterics(_ cbUUID: CBUUID) -> CBMutableService {
        let characteristics: [CBMutableCharacteristic] = CharacteristicType.allCases.compactMap(
            { CBMutableCharacteristic(characteristic: $0) }
        )
        
        let service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = characteristics
        service.includedServices = []
        
        return service
    }
    
    func handle(
        central: any BluetoothCentralProtocol,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        self.subscribedCentrals[characteristic]?
            .removeAll(where: {$0.identifier == central.identifier })
            
        if self.subscribedCentrals[characteristic] == nil {
            self.subscribedCentrals[characteristic] = []
        }
        self.subscribedCentrals[characteristic]?.append(central)
    }
    
    public func handle(
        _ peripheral: any PeripheralManagerProtocol,
        didAdd service: CBService,
        error: (any Error)?
    ) {
        if let error { onError(.addServiceError(error.localizedDescription)) }
    }
    
    func handleDidStartAdvertising(_ peripheral: any PeripheralManagerProtocol, error: (any Error)?) {
        if let error {
            onError(.startAdvertisingError(error.localizedDescription))
        } else {
            print("Advertising started: ", peripheral.isAdvertising)
            delegate?.peripheralSessionDidUpdateState(withError: nil)
        }
    }
    
    func handle(
        _ peripheral: any PeripheralManagerProtocol,
        didReceiveWrite requests: [any ATTRequestProtocol]
    ) {
        print("Received write request of: ", requests)
        let stateRequest = requests.first(
            where: {
                $0.characteristic.uuid ==
                CBUUID(string: CharacteristicType.state.rawValue)
            }
        )
        if stateRequest?.value == ConnectionState.start.data {
            print("Start request received")
        }
    }
    
    private func onError(_ error: PeripheralError) {
        delegate?.peripheralSessionDidUpdateState(withError: error)
        print(error.errorDescription ?? "")
    }
}

extension PeripheralSession: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        handleStateChange(for: peripheral)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        handle(central: central, didSubscribeTo: characteristic)
    }
    
    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: (any Error)?
    ) {
        handleDidStartAdvertising(peripheral, error: error)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: (any Error)?
    ) {
        handle(peripheral, didAdd: service, error: error)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        handle(peripheral, didReceiveWrite: requests)
    }
}

enum ConnectionState: UInt8 {
    case start = 0x01
    case end = 0x02

    var data: Data {
        Data([rawValue])
    }
}

public protocol PeripheralSessionDelegate: AnyObject {
    func peripheralSessionDidUpdateState(withError error: PeripheralError?)
}
