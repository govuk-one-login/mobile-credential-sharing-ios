import Foundation
import PrerequisiteGate

class MockPrerequisiteGateDelegate: PrerequisiteGateDelegate {
    var didUpdateStateCalled: Bool = false
    
    func prerequisiteGateBluetoothDidUpdateState() {
        didUpdateStateCalled = true
    }
}
