import Bluetooth
import Foundation

class MockPeripheralSessionDelegate: PeripheralSessionDelegate {
    var didUpdateState: Bool = false
    
    func peripheralSessionDidUpdateState(withError error: Bluetooth.PeripheralError?) {
        if error != nil {
            didUpdateState = false
        } else {
            didUpdateState = true
        }
    }
}
