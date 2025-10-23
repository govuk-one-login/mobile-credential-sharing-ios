import Foundation
import SwiftCBOR
import Utilities

struct CipherSuite {
    let identifier: UInt64
}

extension CipherSuite {
    public static let iso18013 = CipherSuite(identifier: 1)
}

extension CipherSuite: CBOREncodable {
    
    public func toCBOR(options: SwiftCBOR.CBOROptions) -> CBOR {
        .unsignedInt(identifier)
    }
}
