import Foundation
import SwiftCBOR

public struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
    
    public init(cipherSuiteIdentifier: CipherSuite, eDeviceKey: EDeviceKey) {
        self.cipherSuiteIdentifier = cipherSuiteIdentifier
        self.eDeviceKey = eDeviceKey
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
