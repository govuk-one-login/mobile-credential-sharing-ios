import Foundation

extension UInt32 {
    var bigEndianByteArray: [UInt8] {
        withUnsafeBytes(of: bigEndian, Array.init)
    }
}
