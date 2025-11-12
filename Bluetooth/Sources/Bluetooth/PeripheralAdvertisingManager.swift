import Foundation
import CoreBluetooth

public typealias PeripheralManagerFactory = (
    CBPeripheralManagerDelegate
) -> PeripheralManaging

public final class PeripheralAdvertisingManager: NSObject {
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
    func checkBluetooth() -> Bool {
        guard peripheralManager.state == .poweredOn else {
            return false
        }
        return true
    }
    
    @MainActor
    func addService(_ service: CBMutableService) {
        guard checkBluetooth() else {
            //TODO: add error handling
            return
        }
        
        // Temporarily remove all services at start for easier testing
        addedServices.removeAll()
        peripheralManager.removeAllServices()
        
        if addedServices.contains(service) {
            //TODO: add error handling
            return
        }
        
        peripheralManager.add(service)
        addedServices.append(service)
    }
    
    @MainActor
    func startAdvertising() {
        guard checkBluetooth() else {
            stopAdvertising()
            //TODO: add error handling
            return
        }
        
        guard !addedServices.isEmpty else {
            //TODO: add error handling
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
        if peripheral.state != .poweredOn {
            //TODO: Add error handling
        }
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
