import SharingBluetoothTransport
import SharingPrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
//    weak var delegate: PrerequisiteGateDelegate?
    
    var didCallTriggerResolution: Bool = false
    var notAllowedPrerequisites: [MissingPrerequisite] = [MissingPrerequisite.bluetooth(.authorizationNotDetermined)]
    
    func triggerResolution(for missingPrerequisite: MissingPrerequisite) {
        didCallTriggerResolution = true
    }
    
    func evaluatePrerequisites(
        for required: [Prerequisite],
        completion: @escaping () -> Void
    ) -> [MissingPrerequisite] {
        return notAllowedPrerequisites
    }
}
