import CoreBluetooth
import Foundation

public protocol ATTRequestProtocol {
    var characteristic: CBCharacteristic { get }
    var value: Data? { get }
}

extension CBATTRequest: ATTRequestProtocol {}
