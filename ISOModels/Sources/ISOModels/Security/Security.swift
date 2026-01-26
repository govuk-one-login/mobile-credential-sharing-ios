import Foundation
import SwiftCBOR

enum SecurityError: Error {
    case securityFormatError
    
    public var errorDescription: String? { "The security array didn't contain both a cypher suite and key" }
}

public struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
    
    public init(cipherSuiteIdentifier: CipherSuite, eDeviceKey: EDeviceKey) {
        self.cipherSuiteIdentifier = cipherSuiteIdentifier
        self.eDeviceKey = eDeviceKey
    }
    
    public static func decode(from QRCBOR: [CBOR]) throws -> Self {
        guard case .tagged(let tag, let byteString) = QRCBOR[1] else {
            throw SecurityError.securityFormatError
        }
        let cipherSuite = CipherSuite(identifier: tag.rawValue)
        
        guard case .byteString(let eDeviceKeyBytes) = byteString else {
            throw SecurityError.securityFormatError
        }
        let key = try COSEKey.decode(from: eDeviceKeyBytes)
        
        return Security(cipherSuiteIdentifier: cipherSuite, eDeviceKey: key)
    }
}

extension Security: CBOREncodable {
    public func toCBOR(options: SwiftCBOR.CBOROptions) -> SwiftCBOR.CBOR {
        .array([
            cipherSuiteIdentifier.toCBOR(options: options),
            eDeviceKey.asDataItem(options: options)
        ])
    }
}
