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
    
    init(from qrCBOR: [CBOR]) throws {
        /* take the tagged cbor item from the 2nd position of the array
         this gives the cipher suite as the tag, and the e device key as the item */
        guard case .tagged(let tag, let byteString) = qrCBOR[1] else {
            print(SecurityError.securityFormatError.errorDescription ?? "")
            throw SecurityError.securityFormatError
        }
        let cipherSuite = CipherSuite(identifier: tag.rawValue)
        
        // decode the device key from byte string to byte array
        guard case .byteString(let eDeviceKeyBytes) = byteString else {
            print(SecurityError.securityFormatError.errorDescription ?? "")
            throw SecurityError.securityFormatError
        }
        
        // convert byte array to cbormap
        guard let eDeviceKeyCBOR = try CBOR.decode(eDeviceKeyBytes) else {
            print(KeyError.cannotDecode.errorDescription ?? "")
            throw KeyError.cannotDecode
        }
        let key = try COSEKey(from: eDeviceKeyCBOR)
        
        self.cipherSuiteIdentifier = cipherSuite
        self.eDeviceKey = key
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
