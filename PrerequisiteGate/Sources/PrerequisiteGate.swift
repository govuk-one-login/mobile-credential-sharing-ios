import BluetoothTransport
import Foundation

public protocol PrerequisiteGateProtocol {
    var peripheralSession: PeripheralSession? { get set }
    var delegate: PrerequisiteGateDelegate? { get set }
    func requestPermission(for capability: Capability)
    func checkCapabilities(for capabilites: [Capability]) -> [Capability]
}

public protocol PrerequisiteGateDelegate: AnyObject {
    func bluetoothTransportDidUpdateState(withError error: PeripheralError?)
}

public class PrerequisiteGate: NSObject, PrerequisiteGateProtocol {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    public var peripheralSession: PeripheralSession?
    public weak var delegate: PrerequisiteGateDelegate?
    
    public func requestPermission(for capability: Capability) {
        switch capability {
        case .bluetooth:
            peripheralSession = PeripheralSession(serviceUUID: UUID())
            peripheralSession?.delegate = self
            return
        case .camera:
            return
        }
    }
    
    public func checkCapabilities(for capabilites: [Capability] = Capability.allCases) -> [Capability] {
        return capabilites.filter { capability in
            switch capability {
            case .bluetooth:
                return bluetoothIsNotReady(capability)
            case .camera:
                return true
            }
        }
    }
    
    private func bluetoothIsNotReady(_ capability: Capability) -> Bool {
        !capability.isAllowed || !(peripheralSession?.isReadyToAdvertise() ?? false)
    }
}

extension PrerequisiteGate: PeripheralSessionDelegate {
    public func peripheralSessionDidUpdateState(withError error: PeripheralError?) {
        delegate?.bluetoothTransportDidUpdateState(withError: error)
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
        
    }
}
