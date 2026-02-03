import Foundation
import SwiftCBOR

public enum Curve: UInt64, Sendable {
    case p256 = 1
    case p384 = 2
    case p521 = 3
    case x25519 = 4
    case x448 = 5
    case ed25519 = 6
    case ed448 = 7
    case secp256k1 = 8
    case brainpoolP256r1 = 256
    case brainpoolP320r1 = 257
    case brainpoolP384r1 = 258
    case brainpoolP512r1 = 259
}

extension Curve {
    public var keyType: KeyType {
        switch self {
        case .p256, .p384, .p521, .secp256k1,
             .brainpoolP256r1, .brainpoolP320r1, .brainpoolP384r1, .brainpoolP512r1:
            return .ec2
        case .x25519, .x448, .ed25519, .ed448:
            return .okp
        }
    }
}

extension Curve: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        .unsignedInt(rawValue)
    }
}
