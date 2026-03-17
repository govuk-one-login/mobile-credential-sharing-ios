import SharingBluetoothTransport
import SharingPrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
    weak var delegate: PrerequisiteGateDelegate?
    
    var didCallRequestPermission: Bool = false
    var notAllowedCapabilities: [MissingCapability] = [MissingCapability(type: .bluetooth, reason: .bluetoothAuthNotDetermined)]
    
    func requestPermission(for missingCapability: MissingCapability) {
        didCallRequestPermission = true
    }
    
    func checkCapabilities(for capabilities: [Capability]) -> [MissingCapability] {
        return notAllowedCapabilities
    }
}
