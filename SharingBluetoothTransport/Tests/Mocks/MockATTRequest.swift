import CoreBluetooth
import Foundation
@testable import SharingBluetoothTransport

class MockATTRequest: ATTRequestProtocol {
    var characteristic: CBCharacteristic
    var value: Data?

    init(characteristic: CBCharacteristic, value: Data? = nil) {
        self.characteristic = characteristic
        self.value = value
    }
}
