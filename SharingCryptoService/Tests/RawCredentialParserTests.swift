import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("RawCredentialParser Tests")
struct RawCredentialParserTests {
    let sut = RawCredentialParser()

    @Test("Successfully parses a valid raw credential and extracts docType")
    func parsesValidCredential() throws {
        // Given
        let mso: CBOR = .map([.utf8String("docType"): .utf8String("org.iso.18013.5.1.mDL")])
        let msoBytes = mso.encode()
        let payload: CBOR = .tagged(.encodedCBORDataItem, .byteString(msoBytes))
        let payloadBytes = payload.encode()
        let issuerAuth: CBOR = .array([.null, .null, .byteString(payloadBytes)])
        let root: CBOR = .map([.utf8String("issuerAuth"): issuerAuth])
        let data = Data(root.encode())

        // When
        let result = try sut.parse(rawCredential: data)

        // Then
        #expect(result.docType == "org.iso.18013.5.1.mDL")
    }

    @Test("Throws msoDecodingFailed when issuerAuth is missing")
    func throwsWhenIssuerAuthMissing() {
        // Given
        let root: CBOR = .map([.utf8String("other"): .null])
        let data = Data(root.encode())

        // Then
        #expect(throws: RawCredentialParseError.msoDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws msoDecodingFailed when issuerAuth has fewer than 3 elements")
    func throwsWhenIssuerAuthTooShort() {
        // Given
        let issuerAuth: CBOR = .array([.null, .null])
        let root: CBOR = .map([.utf8String("issuerAuth"): issuerAuth])
        let data = Data(root.encode())

        // Then
        #expect(throws: RawCredentialParseError.msoDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws msoDecodingFailed when payload is not a tagged CBOR data item")
    func throwsWhenPayloadNotTagged() {
        // Given
        let payload: CBOR = .map([.utf8String("docType"): .utf8String("mDL")])
        let payloadBytes = payload.encode()
        let issuerAuth: CBOR = .array([.null, .null, .byteString(payloadBytes)])
        let root: CBOR = .map([.utf8String("issuerAuth"): issuerAuth])
        let data = Data(root.encode())

        // Then
        #expect(throws: RawCredentialParseError.msoDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws msoDecodingFailed when MSO map has no docType")
    func throwsWhenDocTypeMissing() {
        // Given
        let mso: CBOR = .map([.utf8String("version"): .utf8String("1.0")])
        let msoBytes = mso.encode()
        let payload: CBOR = .tagged(.encodedCBORDataItem, .byteString(msoBytes))
        let payloadBytes = payload.encode()
        let issuerAuth: CBOR = .array([.null, .null, .byteString(payloadBytes)])
        let root: CBOR = .map([.utf8String("issuerAuth"): issuerAuth])
        let data = Data(root.encode())

        // Then
        #expect(throws: RawCredentialParseError.msoDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }
}
