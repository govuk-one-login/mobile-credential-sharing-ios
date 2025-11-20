import CoreBluetooth
import Foundation

public final class PeripheralBluetoothSession: NSObject {
    var error: PeripheralManagerError?
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
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
        let characteristic = CBMutableCharacteristic(
            type: CBUUID(nsuuid: UUID()),
            properties: [.notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let descriptor = CBMutableDescriptor(
            type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
            value: "Characteristic"
        )
        characteristic.descriptors = [descriptor]
        
        let service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = [characteristic]
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
        self.subscribedCentrals[characteristic]?.removeAll(where: {$0 == central})
        self.subscribedCentrals[characteristic]?.append(central)
        
        //TODO: Extract to function that can throw
        guard let mutable = characteristic as? CBMutableCharacteristic else {
            error = .updateValueError("Characteristic cannot be made mutable")
            return
        }
        guard peripheralManager
            .updateValue(
                ConnectionState.start.data,
                for: characteristic as! CBMutableCharacteristic,
                onSubscribedCentrals: nil
            ) else {
            error = .unknown
            return
        }
    }
    
    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: (any Error)?
    ) {
        print("Advertising started: ", peripheral.isAdvertising)
        if let error {
            self.error = .startAdvertisingError(error.localizedDescription)
        }
    }
}
