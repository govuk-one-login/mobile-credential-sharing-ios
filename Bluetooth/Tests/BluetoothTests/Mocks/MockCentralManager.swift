import Bluetooth
import Foundation

class MockCentralManager: CentralManaging {
    var identifier: UUID = UUID()
    var maximumUpdateValueLength: Int = 1
}
