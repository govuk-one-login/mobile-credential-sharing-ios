import CoreBluetooth
import Foundation

typealias PeripheralManagerFactory = (
    CBPeripheralManagerDelegate
) -> PeripheralManaging

public final class PeripheralAdvertisingManager: NSObject {
    var error: PeripheralManagerError?
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
    private(set) var addedServices: [CBMutableService] = []
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    
    public lazy var peripheralManager: PeripheralManaging = {
        peripheralManagerFactory(self)
    }()
    private var peripheralManagerFactory: PeripheralManagerFactory
    
    init(
        peripheralManagerFactory: @escaping PeripheralManagerFactory = CBPeripheralManager.default
    ) {
        self.peripheralManagerFactory = peripheralManagerFactory
    }
    
    public convenience override init() {
        self.init(peripheralManagerFactory: CBPeripheralManager.default)
    }
}

public extension PeripheralAdvertisingManager {
    func checkBluetooth(_ state: CBManagerState? = nil) -> Bool {
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
        case .none:
            // Used to prompt initial bluetooth permission check
            return true
        @unknown default:
            error = .unknown
            print("Unknown error that is not covered already")
        }
        return false
    }
    
    @MainActor
    func addService(_ service: CBMutableService) {
        guard checkBluetooth(peripheralManager.state) else {
            return
        }
        
        // Temporarily remove all services at start for easier testing
        addedServices.removeAll()
        peripheralManager.removeAllServices()
        
        if addedServices.contains(service) {
            error = .addServiceError("Already contains this service")
            return
        }
        
        peripheralManager.add(service)
        addedServices.append(service)
    }
    
    @MainActor
    func startAdvertising() {
        guard checkBluetooth(peripheralManager.state) else {
            stopAdvertising()
            return
        }
        
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
    
    @MainActor
    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }
}

extension PeripheralAdvertisingManager: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(
        _ peripheral: CBPeripheralManager
    ) {
        _ = checkBluetooth(peripheral.state)
    }
    
    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        willRestoreState dict: [String: Any]
    ) {
        print("will restore: ", dict)
        let restoredServices = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] ?? []

        self.addedServices = restoredServices
        restoredServices
            .flatMap { $0.characteristics ?? [] }
            .compactMap { $0 as? CBMutableCharacteristic }
            .forEach {
                self.subscribedCentrals[$0] = $0.subscribedCentrals
            }
        
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        print("Advertising started: ", peripheral.isAdvertising)
    }
}
