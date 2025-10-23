import Foundation
import SwiftCBOR

struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
}

extension Security: CBOREncodable {
    public func toCBOR(options: SwiftCBOR.CBOROptions) -> SwiftCBOR.CBOR {
        .array([
            cipherSuiteIdentifier.toCBOR(options: options),
            eDeviceKey.asDataItem(options: options)
        ])
    }
}
