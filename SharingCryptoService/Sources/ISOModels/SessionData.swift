import Foundation
import SwiftCBOR

public enum SessionDataStatusCode: UInt64 {
    case sessionEncryption = 10
    case cborDecoding = 11
    case sessionTermination = 20
}

public struct SessionData {
    public let data: Data?
    public let status: SessionDataStatusCode?

    public init(data: Data? = nil, status: SessionDataStatusCode? = nil) {
        self.data = data
        self.status = status
    }
}

extension SessionData: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [:]

        if let data {
            map[.data] = .byteString([UInt8](data))
        }

        if let status {
            map[.status] = .unsignedInt(status.rawValue)
        }

        return .map(map)
    }
}

fileprivate extension CBOR {
    static var data: CBOR { "data" }
    static var status: CBOR { "status" }
}
