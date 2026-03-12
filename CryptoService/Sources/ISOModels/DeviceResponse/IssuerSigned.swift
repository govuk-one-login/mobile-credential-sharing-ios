import Foundation
import SwiftCBOR

public struct IssuerSigned {
    let nameSpaces: [String: [IssuerSignedItem]]
    let issuerAuth: [UInt8]
    
    public init(nameSpaces: [String: [IssuerSignedItem]], issuerAuth: [UInt8]) {
        self.nameSpaces = nameSpaces
        self.issuerAuth = issuerAuth
    }
}

extension IssuerSigned: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .nameSpaces: .map(nameSpaces.mapKeys { .utf8String($0) }.mapValues { items in
                .array(items.map { $0.toCBOR(options: options) })
            }),
            .issuerAuth: .byteString(issuerAuth)
        ])
    }
}

fileprivate extension CBOR {
    static var nameSpaces: CBOR { "nameSpaces" }
    static var issuerAuth: CBOR { "issuerAuth" }
}

fileprivate extension Dictionary {
    func mapKeys<T>(_ transform: (Key) -> T) -> [T: Value] {
        [T: Value](uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}
