import Foundation
import SwiftCBOR

public struct ParsedRawCredential: Sendable {
    public let docType: String
    public let nameSpaces: [String: [IssuerSignedItemBytes]]
    public let issuerAuth: [UInt8]
}

/// Wraps a decoded elementIdentifier with the original Tag 24 CBOR for MSO integrity.
public struct IssuerSignedItemBytes: Equatable, Sendable {
    public let elementIdentifier: String
    public let elementValue: CBOR
    public let rawCBOR: CBOR

    public init(elementIdentifier: String, elementValue: CBOR, rawCBOR: CBOR) {
        self.elementIdentifier = elementIdentifier
        self.elementValue = elementValue
        self.rawCBOR = rawCBOR
    }
}
