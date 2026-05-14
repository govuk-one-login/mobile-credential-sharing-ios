import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("RawCredentialParser Tests")
struct RawCredentialParserTests {
    let sut = RawCredentialParser()
    
    // MARK: - Helpers
    /// Builds a valid root CBOR (passes MSO parsing) with a custom nameSpaces value
    private func validRootWithNameSpaces(_ nameSpaces: CBOR) -> CBOR {
        let mso: CBOR = .map([.utf8String("docType"): .utf8String("org.iso.18013.5.1.mDL")])
        let payload: CBOR = .tagged(.encodedCBORDataItem, .byteString(mso.encode()))
        let issuerAuth: CBOR = .array([.null, .null, .byteString(payload.encode())])
        return .map([
            .utf8String("issuerAuth"): issuerAuth,
            .utf8String("nameSpaces"): nameSpaces
        ])
    }

    @Test("Successfully parses a valid raw credential and extracts docType")
    func parsesValidCredential() throws {
        // Given
        let itemCBOR: CBOR = .map([
            .utf8String("elementIdentifier"): .utf8String("family_name"),
            .utf8String("elementValue"): .utf8String("Smith")
        ])
        let nameSpaces: CBOR = .map([
            .utf8String("org.iso.18013.5.1"): .array([
                .tagged(.encodedCBORDataItem, .byteString(itemCBOR.encode()))
            ])
        ])
        let root: CBOR = validRootWithNameSpaces(nameSpaces)
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

    // MARK: - parseNameSpaces error paths
    @Test("Throws nameSpacesDecodingFailed when nameSpaces key is missing")
    func throwsWhenNameSpacesMissing() {
        // Given
        let data = Data(validRootWithNameSpaces(.null).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws nameSpacesDecodingFailed when nameSpaces value is not a map")
    func throwsWhenNameSpacesNotMap() {
        // Given
        let data = Data(validRootWithNameSpaces(.array([.null])).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws nameSpacesDecodingFailed when namespace value is not an array")
    func throwsWhenNameSpaceValueNotArray() {
        // Given
        let nameSpaces: CBOR = .map([.utf8String("org.iso.18013.5.1"): .utf8String("invalid")])
        let data = Data(validRootWithNameSpaces(nameSpaces).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws nameSpacesDecodingFailed when namespace key is not a string")
    func throwsWhenNameSpaceKeyNotString() {
        // Given
        let nameSpaces: CBOR = .map([.unsignedInt(1): .array([])])
        let data = Data(validRootWithNameSpaces(nameSpaces).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws nameSpacesDecodingFailed when item is not a Tag 24")
    func throwsWhenItemNotTagged() {
        // Given
        let nameSpaces: CBOR = .map([
            .utf8String("org.iso.18013.5.1"): .array([.utf8String("not a tag")])
        ])
        let data = Data(validRootWithNameSpaces(nameSpaces).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }

    @Test("Throws nameSpacesDecodingFailed when item has no elementIdentifier")
    func throwsWhenItemMissingElementIdentifier() {
        // Given
        let itemWithoutIdentifier: CBOR = .map([
            .utf8String("digestID"): .unsignedInt(0),
            .utf8String("elementValue"): .utf8String("value")
        ])
        let nameSpaces: CBOR = .map([
            .utf8String("org.iso.18013.5.1"): .array([
                .tagged(.encodedCBORDataItem, .byteString(itemWithoutIdentifier.encode()))
            ])
        ])
        let data = Data(validRootWithNameSpaces(nameSpaces).encode())

        // Then
        #expect(throws: RawCredentialParseError.nameSpacesDecodingFailed) {
            try sut.parse(rawCredential: data)
        }
    }
}
