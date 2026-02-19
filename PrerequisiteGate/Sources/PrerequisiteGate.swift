import BluetoothTransport
import CoreBluetooth
import Foundation

public protocol PrerequisiteGateProtocol {
    var peripheralSession: PeripheralSessionProtocol? { get set }
    var delegate: PrerequisiteGateDelegate? { get set }
    func requestPermission(for capability: Capability)
    func checkCapabilities(for capabilites: [Capability]) -> [Capability]
}

public protocol PrerequisiteGateDelegate: AnyObject {
    func bluetoothTransportDidUpdateState()
}

public class PrerequisiteGate: NSObject, PrerequisiteGateProtocol {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    public var peripheralSession: PeripheralSessionProtocol?
    public weak var delegate: PrerequisiteGateDelegate?
    private let cbManagerAuthorization: () -> CBManagerAuthorization
    let cbPeripheralManagerShowPowerAlertKey: Bool = true
    
    // Public init with no parameters to expose to consumer
    public convenience override init() {
        self.init(cbManagerAuthorization: CBManager.authorization)
    }

    // Internal init for testing purposes
    internal init(
        cbManagerAuthorization: @autoclosure @escaping () -> CBManagerAuthorization
    ) {
        self.cbManagerAuthorization = cbManagerAuthorization
    }
 
    public func requestPermission(for capability: Capability) {
        switch capability {
        case .bluetooth(let reason):
            switch reason {
            case .bluetoothAuthNotDetermined:
                peripheralSession = PeripheralSession(serviceUUID: UUID())
                peripheralSession?.delegate = self
            case .bluetoothStatePoweredOff:
                _ = CBPeripheralManager(
                    delegate: nil,
                    queue: nil,
                    options: [
                        CBPeripheralManagerOptionShowPowerAlertKey: cbPeripheralManagerShowPowerAlertKey
                    ]
                )
            default:
                break
            }
            return
        case .camera:
            // Camera permission requests for Verifier
            return
        }
    }
    
    public func checkCapabilities(for capabilites: [Capability] = Capability.allCases) -> [Capability] {
        capabilites.compactMap { capability in
            // self.cbManagerAuthorization should only be non-nil in testing environment
            let auth = self.cbManagerAuthorization()
            switch capability {
            case .bluetooth:
                switch auth {
                case .allowedAlways:
                    return checkAndHandleBluetoothState()
                case .notDetermined:
                    return .bluetooth(.bluetoothAuthNotDetermined)
                case .denied:
                    return .bluetooth(.bluetoothAuthDenied)
                case .restricted:
                    return .bluetooth(.bluetoothAuthRestricted)
                default:
                    return nil
                }
            case .camera:
                return nil
            }
        }
    }
    
    private func checkAndHandleBluetoothState() -> Capability? {
        if peripheralSession == nil {
            peripheralSession = PeripheralSession(
                serviceUUID: UUID()
            )
            peripheralSession?.delegate = self
        }
        switch peripheralSession?.peripheralManagerState() {
        case .poweredOn:
            return nil
        case .poweredOff:
            return .bluetooth(.bluetoothStatePoweredOff)
        case .resetting:
            return .bluetooth(.bluetoothStateResetting)
        case .unsupported:
            return .bluetooth(.bluetoothStateUnsupported)
        case .unknown:
            return .bluetooth(.bluetoothStateUnknown)
        case .unauthorized:
            return .bluetooth(.bluetoothAuthDenied)
        default:
            return nil
        }
    }
}

extension PrerequisiteGate: PeripheralSessionDelegate {
    public func peripheralSessionDidUpdateState(withError error: PeripheralError?) {
        delegate?.bluetoothTransportDidUpdateState()
    }
    
    public func peripheralSessionDidStartAdvertising() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func peripheralSessionDidReceiveMessageEndRequest() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func peripheralSessionDidAddService() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
}
