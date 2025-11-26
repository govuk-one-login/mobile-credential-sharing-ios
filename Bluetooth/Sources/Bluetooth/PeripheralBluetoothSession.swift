import CoreBluetooth
import Foundation

public final class PeripheralBluetoothSession: NSObject {
    var error: PeripheralManagerError?
    
    private(set) var subscribedCentrals: [CBCharacteristic: [BluetoothCentral]] = [:]
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    private(set) var serviceCBUUID: CBUUID
    
    private var peripheralManager: PeripheralManaging
    
    init(
        peripheralManager: PeripheralManaging,
        serviceUUID: UUID,
    ) {
        self.peripheralManager = peripheralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.peripheralManager.delegate = self
    }
    
    public convenience override init() {
        self.init(
            peripheralManager: CBPeripheralManager(delegate: nil, queue: nil, options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]),
            serviceUUID: UUID(
                // Hard coding the UUID for now, for easier tracking
                uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE"
            ) ?? UUID()
        )
    }
    
    deinit {
        self.stopAdvertising()
    }
}

extension PeripheralBluetoothSession {
    func checkBluetooth(_ state: CBManagerState) -> Bool {
        switch state {
        case .poweredOn:
            return true
        case .unauthorized:
            error = .permissionsNotAccepted
            print("Bluetooth is unauthorized")
        case .poweredOff:
            error = .bluetoothNotEnabled
            print("Bluetooth is powered off")
        case .resetting:
            error = .bluetoothNotEnabled
            print("Bluetooth is resetting")
        case .unsupported:
            error = .bluetoothNotEnabled
            print("Bluetooth is unsupported")
        case .unknown:
            error = .unknown
            print("Unknown error")
        @unknown default:
            error = .unknown
            print("Unknown error that is not covered already")
        }
        stopAdvertising()
        return false
    }
    
    func addService(_ cbUUID: CBUUID) -> CBMutableService {
        let characteristics: [CBMutableCharacteristic] = CharacteristicType.allCases.compactMap(
            { CBMutableCharacteristic(characteristic: $0) }
        )
        
        let service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = characteristics
        service.includedServices = []
        
        return service
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
    
    func initiateAdvertising(_ peripheral: any PeripheralManaging) {
        guard checkBluetooth(peripheral.state) else {
            return
        }
        
        let service = self.addService(self.serviceCBUUID)
        peripheral.removeAllServices()
        peripheral.add(service)
        peripheralManager
            .startAdvertising(
                [CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
            )
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
    
    func handleError(_ error: PeripheralManagerError) {
        self.error = error
    }
}

extension PeripheralBluetoothSession: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        initiateAdvertising(peripheral)
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
    
    // TODO: DCMAW-16530 - Add this delegate method to check for connection start
    //    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
    //        print("Received write request of: ", requests)
    //        if requests.first?.value == ConnectionState.start.data {
    //            // This is the 'Start' request - ie 0x01
    //        }
    //    }
}
