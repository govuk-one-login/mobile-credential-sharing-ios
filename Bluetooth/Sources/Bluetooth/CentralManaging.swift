import CoreBluetooth
import Foundation

public protocol CentralManaging {
    var identifier: UUID { get }
    var maximumUpdateValueLength: Int { get }
}

extension CBCentral: CentralManaging {}
