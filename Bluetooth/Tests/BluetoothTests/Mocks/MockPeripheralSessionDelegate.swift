import Bluetooth
import Foundation

class MockPeripheralSessionDelegate: PeripheralSessionDelegate {
    var didUpdateState: Bool?
    var didThrowError: Bluetooth.PeripheralError?
    
    func peripheralSessionDidUpdateState(withError error: Bluetooth.PeripheralError?) {
        if error != nil {
            didUpdateState = false
            didThrowError = error
        } else {
            didUpdateState = true
            didThrowError = nil
        }
    }
}
