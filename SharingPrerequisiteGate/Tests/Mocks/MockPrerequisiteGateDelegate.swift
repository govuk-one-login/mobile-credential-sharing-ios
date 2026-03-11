import Foundation
import PrerequisiteGate

class MockPrerequisiteGateDelegate: PrerequisiteGateDelegate {
    var didReportChangeCalled: Bool = false
    
    func prerequisiteGateBluetoothDidReportChange() {
        didReportChangeCalled = true
    }
}
