import CoreBluetooth
import Foundation

public final class PeripheralSession: NSObject {
    private(set) var subscribedCentrals: [CBCharacteristic: [BluetoothCentral]] = [:]
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
        let authorization: CBManagerAuthorization = type(of: peripheral).authorization
        switch authorization {
        case .allowedAlways:
            startAdvertisingIfPoweredOn(peripheral)
        case .notDetermined, .restricted, .denied:
            handleError(.permissionsNotGranted(authorization))
        @unknown default:
            handleError(.unknown)
        }
    }
    
    private func startAdvertisingIfPoweredOn(_ peripheral: any PeripheralManagerProtocol) {
        switch peripheral.state {
        case .poweredOn:
            startAdvertising(peripheral)
        case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
            handleError(.notPoweredOn(peripheral.state))
        @unknown default:
            handleError(.unknown)
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
    
    func centralDidSubscribe(
        central: any BluetoothCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        self.subscribedCentrals[characteristic]?
            .removeAll(where: {$0.identifier == central.identifier })
            
        if self.subscribedCentrals[characteristic] == nil {
            self.subscribedCentrals[characteristic] = []
        }
        self.subscribedCentrals[characteristic]?.append(central)
    }
    
    private func handleError(_ error: PeripheralError) {
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
        centralDidSubscribe(central: central, didSubscribeTo: characteristic)
    }
    
    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: (any Error)?
    ) {
        if let error { handleError(.startAdvertisingError(error.localizedDescription)) }
        print("Advertising started: ", peripheral.isAdvertising)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: (any Error)?
    ) {
        if let error { handleError(.addServiceError(error.localizedDescription)) }
    }
    
    // TODO: DCMAW-17058 - To implement with receiving SessionEstablishment
//        public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//            print("Received write request of: ", requests)
//            if requests.first?.value == ConnectionState.start.data {
//                // This is the 'Start' request - ie 0x01
//            }
//        }
//    enum ConnectionState: UInt8 {
//        case start = 0x01
//        case end = 0x02
//
//        var data: Data {
//            Data([rawValue])
//        }
//    }
}
