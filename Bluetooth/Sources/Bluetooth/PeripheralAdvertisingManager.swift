import CoreBluetooth
import Foundation

public typealias PeripheralManagerFactory = (
    CBPeripheralManagerDelegate
) -> PeripheralManaging

public final class PeripheralAdvertisingManager: NSObject {
    var error: PeripheralManagerError?
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
    private(set) var addedServices: [CBMutableService] = []
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    
    private lazy var peripheralManager: PeripheralManaging = {
        peripheralManagerFactory(self)
    }()
    private var peripheralManagerFactory: PeripheralManagerFactory
    
    public init(
        peripheralManagerFactory: @escaping PeripheralManagerFactory = CBPeripheralManager.default
    ) {
        self.peripheralManagerFactory = peripheralManagerFactory
    }
}

public extension PeripheralAdvertisingManager {
    func checkBluetooth(_ state: CBManagerState) -> Bool {
        switch state {
        case .poweredOn:
            return true
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Unknown error")
        @unknown default:
            print("Unknown error")
        }
        return false
    }
    
    @MainActor
    func addService(_ service: CBMutableService) {
        guard checkBluetooth(peripheralManager.state) else {
            error = .bluetoothNotEnabled
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
            error = .bluetoothNotEnabled
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
