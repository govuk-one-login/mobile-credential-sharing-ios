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

public struct PrerequisiteGate {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    var temporaryPeripheralManager: CBPeripheralManager?
    var temporaryPeripheralManagerDelegate = TemporaryPeripheralManagerDelegate()
    
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
                delegate: nil,
                queue: nil,
                options: [
                    CBPeripheralManagerOptionShowPowerAlertKey: true
                ]
            )
            temporaryPeripheralManager?.delegate = temporaryPeripheralManagerDelegate
            return
        case .camera:
            return
        }
    }
}

class TemporaryPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // TODO: Add delegate function to call Orchestrator and re-do checks for bluetooth for when the OS BT permissions have been granted
        // delegate.didUpdatePermissionState(peripheral.state)
        print("Updated state")
    }
}
