import CoreBluetooth
import Foundation

public protocol BluetoothCentralProtocol {
    /// The unique, persistent identifier associated with the peer.
    var identifier: UUID { get }
    
    /// The maximum amount of data, in bytes, that the central can receive in a single notification or indication.
    var maximumUpdateValueLength: Int { get }
}

extension CBCentral: BluetoothCentralProtocol {}
