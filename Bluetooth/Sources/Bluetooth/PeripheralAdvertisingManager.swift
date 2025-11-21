import CoreBluetooth
import Foundation

public final class PeripheralAdvertisingManager: NSObject {
    var error: PeripheralManagerError?
    public var beginAdvertising: Bool = false
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CentralManaging]] = [:]
    private(set) var addedServices: [CBMutableService] = []
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    
    public var peripheralManager: PeripheralManaging
    
    init(
        peripheralManager: PeripheralManaging
    ) {
        self.peripheralManager = peripheralManager
        super.init()
        self.peripheralManager.delegate = self
        
    }
    
    public convenience override init() {
        self.init(peripheralManager: CBPeripheralManager(delegate: nil, queue: nil, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true
        ]))
    }
}

public extension PeripheralAdvertisingManager {
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
        var characteristics = [CBMutableCharacteristic]()
        for characteristic in ServiceCharacteristic.allCases {
            let serviceCharacteristic = CBMutableCharacteristic(
                type: CBUUID(string: characteristic.rawValue),
                properties: characteristic.properties,
                value: nil,
                permissions: [.readable, .writeable]
            )
            let descriptor = CBMutableDescriptor(
                type: CBUUID(string: CBUUIDCharacteristicUserDescriptionString),
                value: "\(characteristic) characteristic"
            )
            serviceCharacteristic.descriptors = [descriptor]
            
            characteristics.append(serviceCharacteristic)
        }
        
        let service = CBMutableService(type: cbUUID, primary: true)
        
        service.characteristics = characteristics
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
    }
    
    func initiateAdvertising(_ peripheral: any PeripheralManaging) {
        if let service = addedServices.last, beginAdvertising {
            peripheral.removeAllServices()
            peripheral.add(service)
            startAdvertising()
        }
    }
    
    func centralDidSubscribe(
        central: any CentralManaging,
        didSubscribeTo characteristic: CBCharacteristic) {
            if ((central as? CBCentral) != nil) {
                self.subscribedCentrals[characteristic]?
                    .removeAll(where: {$0 as? CBCentral == central as? CBCentral})
            }
            
            if self.subscribedCentrals[characteristic] == nil {
                self.subscribedCentrals[characteristic] = []
            }
            self.subscribedCentrals[characteristic]?.append(central)
        }
}

extension PeripheralAdvertisingManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        guard checkBluetooth(peripheral.state) else {
            return
        }
        self.initiateAdvertising(peripheral)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        self.centralDidSubscribe(central: central, didSubscribeTo: characteristic)
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
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        if let error {
            self.error = .addServiceError(error.localizedDescription)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        print("Received write request of: ", requests)
        if requests.first?.value == ConnectionState.start.data {
            // This is the 'Start' request - ie 0x01
        }
    }
}

extension CBCentral: CentralManaging {}


public protocol CentralManaging {
    var maximumUpdateValueLength: Int { get }
}
