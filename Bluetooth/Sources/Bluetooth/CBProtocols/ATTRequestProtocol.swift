import CoreBluetooth
import Foundation

protocol ATTRequestProtocol {
    var characteristic: CBCharacteristic { get }
    var value: Data? { get }
}

extension CBATTRequest: ATTRequestProtocol {}
