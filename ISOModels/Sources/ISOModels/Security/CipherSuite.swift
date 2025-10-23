import Foundation
import SwiftCBOR
import Utilities

public struct CipherSuite: Sendable {
    let identifier: UInt64
    
    public init(identifier: UInt64) {
        self.identifier = identifier
    }
}

extension CipherSuite {
    public static let iso18013 = CipherSuite(identifier: 1)
}

extension CipherSuite: CBOREncodable {
    
    public func toCBOR(options: SwiftCBOR.CBOROptions) -> CBOR {
        .unsignedInt(identifier)
    }
}
