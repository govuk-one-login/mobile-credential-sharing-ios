import Foundation
import SwiftCBOR

public struct SessionData {
    public let data: Data?
    public let status: UInt64?

    public init(data: Data? = nil, status: UInt64? = nil) {
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
            map[.status] = .unsignedInt(status)
        }

        return .map(map)
    }
}

fileprivate extension CBOR {
    static var data: CBOR { "data" }
    static var status: CBOR { "status" }
}
