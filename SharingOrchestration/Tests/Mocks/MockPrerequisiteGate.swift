import SharingBluetoothTransport
import SharingPrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
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
