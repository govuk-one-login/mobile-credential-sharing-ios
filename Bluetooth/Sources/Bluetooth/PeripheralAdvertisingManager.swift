import CoreBluetooth
import Foundation

public final class PeripheralAdvertisingManager: NSObject {
    var error: PeripheralManagerError?
    var beginAdvertising: Bool = false
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
    private(set) var addedServices: [CBMutableService] = []
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    private(set) var serviceCBUUID: CBUUID
    
    private var peripheralManager: PeripheralManaging
    
    init(
        peripheralManager: PeripheralManaging,
        serviceUUID: UUID,
        beginAdvertising: Bool
    ) {
        self.peripheralManager = peripheralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.peripheralManager.delegate = self
        
        self.removeServices()
        self.addService(self.serviceCBUUID)
        self.beginAdvertising = beginAdvertising
    }
    
    public convenience override init() {
        self.init(
            peripheralManager: CBPeripheralManager(delegate: nil, queue: nil, options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]),
            serviceUUID: UUID(
                // Hard coding the UUID for now, for easier tracking
                uuidString: "61E1BEB4-5AB3-4997-BF92-D0696A3D9CCE"
            ) ?? UUID(),
            beginAdvertising: true
        )
    }
    
    deinit {
        self.stopAdvertising()
    }
}

extension PeripheralAdvertisingManager {
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
        return false
    }
    
    func addService(_ cbUUID: CBUUID) {
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
        
        if addedServices.contains(where: { $0.uuid == cbUUID }) {
            error = .addServiceError("Already contains this service")
            return
        }
        
        addedServices.append(service)
    }
    
    func removeServices() {
        addedServices.removeAll()
    }
    
    func startAdvertising() {
        guard !addedServices.isEmpty else {
            error = .addServiceError("Added services cannot be empty")
            return
        }
        
        peripheralManager
            .startAdvertising(
                [CBAdvertisementDataServiceUUIDsKey: addedServices.map {
                    print("advertised service ID is:", $0.uuid)
                    return $0.uuid
                }]
            )
        
    }
    
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        beginAdvertising = false
    }
    
    func initiateAdvertising(_ peripheral: any PeripheralManaging) {
        guard checkBluetooth(peripheral.state) else {
            return
        }
        if let service = addedServices.last, beginAdvertising {
            peripheral.removeAllServices()
            peripheral.add(service)
            startAdvertising()
        }
    }
}

extension PeripheralAdvertisingManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        initiateAdvertising(peripheral)
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print("Advertising started: ", peripheral.isAdvertising)
    }
}
