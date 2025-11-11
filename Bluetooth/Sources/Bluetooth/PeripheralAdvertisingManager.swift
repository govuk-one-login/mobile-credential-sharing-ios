import Foundation
import CoreBluetooth

typealias PeripheralManagerFactory = (
    CBPeripheralManagerDelegate
) -> PeripheralManaging

public final class PeripheralAdvertisingManager: NSObject, CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

    }
    
    private(set) var subscribedCentrals: [CBCharacteristic: [CBCentral]] = [:]
    private(set) var addedServices: [CBMutableService] = []
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    
    private lazy var peripheralManager: PeripheralManaging = {
        peripheralManagerFactory(self)
    }()
    private var peripheralManagerFactory: PeripheralManagerFactory
    
    init(peripheralManagerFactory: @escaping PeripheralManagerFactory = CBPeripheralManager.default) {
        self.peripheralManagerFactory = peripheralManagerFactory
    }
}

protocol PeripheralManaging {
    var state: CBManagerState { get }
    
    func startAdvertising(_ advertisementData: [String: Any]?)
    func stopAdvertising()
    
    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    
    func updateValue(
        _ value: Data,
        for characteristic: CBMutableCharacteristic,
        onSubscribedCentrals: [CBCentral]?
    ) -> Bool
}

extension PeripheralManaging where Self == CBPeripheralManager {
    static func `default`(delegate: CBPeripheralManagerDelegate) -> Self {
        CBPeripheralManager(delegate: delegate, queue: nil, options: [
            CBPeripheralManagerOptionShowPowerAlertKey: true,
            CBPeripheralManagerOptionRestoreIdentifierKey: "VPPeripheralManager"
        ])
    }
}

extension CBPeripheralManager: PeripheralManaging { }
