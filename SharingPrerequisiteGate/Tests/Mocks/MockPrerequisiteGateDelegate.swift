import Foundation
import SharingPrerequisiteGate

class MockPrerequisiteGateDelegate: PrerequisiteGateDelegate {
    var didReportChangeCalled: Bool = false
    
    func prerequisiteGateBluetoothDidReportChange() {
        didReportChangeCalled = true
    }
}
