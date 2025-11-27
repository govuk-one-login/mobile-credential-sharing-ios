import Foundation

enum ConnectionState: UInt8 {
    case start = 0x01
    case end = 0x02

    var data: Data {
        Data([rawValue])
    }
}
