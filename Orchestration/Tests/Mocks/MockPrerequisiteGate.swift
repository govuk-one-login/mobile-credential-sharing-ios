import BluetoothTransport
import PrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var peripheralSession: PeripheralSession?
    
    weak var delegate: PrerequisiteGateDelegate?
    
    var notAllowedCapabilities: [Capability] = [.bluetooth()]
    func requestPermission(for capability: Capability) {
        
    }
    
    func checkCapabilities(for capabilites: [Capability]) -> [Capability] {
        return notAllowedCapabilities
    }
}
