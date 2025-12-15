@testable import Bluetooth
import CoreBluetooth
import Foundation

class MockATTRequest: ATTRequestProtocol {
    var characteristic: CBCharacteristic
    var value: Data?
    
    init(characteristic: CBCharacteristic, value: Data? = nil) {
        self.characteristic = characteristic
        self.value = value
    }
}