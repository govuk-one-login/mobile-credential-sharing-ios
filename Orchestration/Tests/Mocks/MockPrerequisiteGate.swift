import BluetoothTransport
import PrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var peripheralSession: PeripheralSessionProtocol?
    
    weak var delegate: PrerequisiteGateDelegate?
    
    var didCallRequestPermission: Bool = false
    var notAllowedCapabilities: [Capability] = [.bluetooth()]
    
    func requestPermission(for capability: Capability) {
        didCallRequestPermission = true
    }
    
    func checkCapabilities(for capabilities: [Capability]) -> [Capability] {
        return notAllowedCapabilities
    }
}
