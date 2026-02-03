import CoreBluetooth
import Foundation

@testable import BluetoothTransport

class MockATTRequest: ATTRequestProtocol {
    var characteristic: CBCharacteristic
    var value: Data?

    init(characteristic: CBCharacteristic, value: Data? = nil) {
        self.characteristic = characteristic
        self.value = value
    }
}
