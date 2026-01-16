import Bluetooth
import Foundation

class MockPeripheralSessionDelegate: PeripheralSessionDelegate {
    var didUpdateState: Bool?
    var didThrowError: Bool?
    
    func peripheralSessionDidUpdateState(withError error: Bluetooth.PeripheralError?) {
        if error != nil {
            didUpdateState = false
            didThrowError = true
        } else {
            didUpdateState = true
        }
    }
}
