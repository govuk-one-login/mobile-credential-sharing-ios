import SharingBluetoothTransport
import SharingPrerequisiteGate

class MockPrerequisiteGate: PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol?
    
    var didCallTriggerResolution: Bool = false
    var notAllowedPrerequisites: [MissingPrerequisite] = [MissingPrerequisite.bluetooth(.authorizationNotDetermined)]
    var evaluatedPrerequisites: [Prerequisite] = []
    
    func triggerResolution(for missingPrerequisite: MissingPrerequisite) {
        didCallTriggerResolution = true
    }
    
    func evaluatePrerequisites(
        for required: [Prerequisite],
        completion: @escaping () -> Void
    ) -> [MissingPrerequisite] {
        evaluatedPrerequisites = required
        return notAllowedPrerequisites
    }
}
