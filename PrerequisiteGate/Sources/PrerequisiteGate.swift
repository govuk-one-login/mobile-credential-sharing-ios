import CoreBluetooth

public protocol PrerequisiteGateDelegate: AnyObject {
    func didUpdatePermissions()
}

public struct PrerequisiteGate {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    var temporaryPeripheralManager: CBPeripheralManager?
    var temporaryPeripheralManagerDelegate = TemporaryPeripheralManagerDelegate()
    public var delegate: PrerequisiteGateDelegate?
    
    public init() {
        // init required to declare struct as public
    }
    
    public mutating func requestPermission(for capability: Capability) {
        switch capability {
        case .bluetooth:
            // Creates an unused CBPeripheralManager, which triggers the OS permissions popup
            temporaryPeripheralManager = CBPeripheralManager(
                delegate: temporaryPeripheralManagerDelegate,
                queue: nil,
                options: [
                    CBPeripheralManagerOptionShowPowerAlertKey: true
                ]
            )
            temporaryPeripheralManagerDelegate.delegate = self.delegate
            return
        case .camera:
            return
        }
    }
    
    public static func checkCapabilities(for capabilites: [Capability] = Capability.allCases) -> [Capability] {
        return capabilites.filter { !$0.isAllowed }
    }
}

class TemporaryPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    weak var delegate: PrerequisiteGateDelegate?
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        delegate?.didUpdatePermissions()
    }
}
