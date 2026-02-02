import Foundation
import SwiftCBOR

public enum KeyType: UInt64 {
    case okp = 1
    case ec2 = 2
}

extension KeyType: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        .unsignedInt(rawValue)
    }
}
