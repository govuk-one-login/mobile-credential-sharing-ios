import Foundation
import SwiftCBOR

extension MockCredential {
    /// Jane Doe credential with only a domestic namespace (`org.iso.18013.5.1.domestic`).
    /// Any standard mDL attribute request against `org.iso.18013.5.1` will trigger
    /// the unfulfillable request path since no matching namespace is found.
    static func janeDoeUnfulfillable() -> MockCredential {
        let issuerSignedItem: CBOR = .tagged(.encodedCBORDataItem, .byteString(
            CBOR.map([
                "digestID": .unsignedInt(0),
                "elementIdentifier": .utf8String("domestic_category"),
                "random": .byteString([UInt8](repeating: 0xAA, count: 16)),
                "elementValue": .utf8String("B")
            ]).encode()
        ))

        let msoPayload: [UInt8] = CBOR.tagged(.encodedCBORDataItem, .byteString(
            CBOR.map([
                "docType": .utf8String("org.iso.18013.5.1.mDL"),
                "version": .utf8String("1.0")
            ]).encode()
        )).encode()

        let credential: CBOR = .map([
            "nameSpaces": .map([
                "org.iso.18013.5.1.domestic": .array([issuerSignedItem])
            ]),
            "issuerAuth": .array([
                .byteString([]),
                .map([:]),
                .byteString(msoPayload),
                .byteString([UInt8](repeating: 0x00, count: 64))
            ])
        ])

        return MockCredential(
            id: "jane-doe-unfulfillable",
            displayName: "Jane Doe (Unfulfillable)",
            rawCredential: Data(credential.encode()),
            privateKey: Data(repeating: 0x01, count: 32)
        )
    }
}
