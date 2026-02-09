import AVFoundation
import CoreBluetooth

public enum Capability: CaseIterable, Sendable {
    case bluetooth
    case camera
   
    var isAllowed: Bool {
        switch self {
        case .bluetooth:
            return CBManager.authorization == .allowedAlways
            //            &&
            //            CBManager.state == .poweredOn
        case .camera:
            return AVCaptureDevice.default(for: .video) != nil &&
            AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        }
    }
}

public protocol PrerequisiteGateDelegate {
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
    
    public static func checkCapabilities(for capabilites: [Capability] = Capability.allCases) -> [Capability] {
        return capabilites.filter { !$0.isAllowed }
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
}

class TemporaryPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    var delegate: PrerequisiteGateDelegate?
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        delegate?.didUpdatePermissions()
    }
}
