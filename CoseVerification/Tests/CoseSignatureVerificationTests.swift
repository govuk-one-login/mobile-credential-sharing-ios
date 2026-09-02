@testable import CoseVerification
import CryptoKit
import Foundation
import Security
import SwiftCBOR
import Testing

@Suite("COSE_Sign1 ES256 signature verification")
struct CoseSignatureVerificationTests {
    
    // MARK: - AC1: Signature input uses the exact bytes selected for the payload mode

    @Test("Sig_structure array has the correct 4 elements")
    func sigStructureShape() throws {
        let protectedHeader = Data([0xA1, 0x01, 0x26])
        let payload = Data([0x01, 0x02, 0x03, 0x04])

        let encoded = SigStructureBuilder.build(
            protectedHeaderBytes: protectedHeader,
            payload: payload
        )

        let decoded = try #require(try CBOR.decode([UInt8](encoded)))
        guard case .array(let elements) = decoded else {
            Issue.record("Sig_structure is not a CBOR array")
            return
        }

        #expect(elements.count == 4)
        #expect(elements[0] == .utf8String("Signature1"))
        #expect(elements[1] == .byteString([UInt8](protectedHeader)))
        #expect(elements[2] == .byteString([])) // empty external AAD
        #expect(elements[3] == .byteString([UInt8](payload)))
    }

    @Test("Protected-header bytes are used unchanged")
    func protectedHeaderBytesUnchanged() throws {
        // A non-canonical protected header encoding must be preserved.
        let nonCanonicalProtectedHeader = Data([0xB9, 0x00, 0x01, 0x01, 0x26])
        let payload = Data([0xAA])

        let encoded = SigStructureBuilder.build(
            protectedHeaderBytes: nonCanonicalProtectedHeader,
            payload: payload
        )

        let decoded = try #require(try CBOR.decode([UInt8](encoded)))
        guard case .array(let elements) = decoded else {
            Issue.record("Sig_structure is not a CBOR array")
            return
        }
        #expect(elements[1] == .byteString([UInt8](nonCanonicalProtectedHeader)))
    }

    @Test("Payload bytes are used unchanged")
    func payloadBytesUnchanged() throws {
        let protectedHeader = es256ProtectedHeader
        let payload = Data([0x00, 0x11, 0x22, 0x33, 0x44, 0x55])

        let encoded = SigStructureBuilder.build(
            protectedHeaderBytes: protectedHeader,
            payload: payload
        )

        let decoded = try #require(try CBOR.decode([UInt8](encoded)))
        guard case .array(let elements) = decoded else {
            Issue.record("Sig_structure is not a CBOR array")
            return
        }
        #expect(elements[3] == .byteString([UInt8](payload)))
    }

    @Test("Attached mode selects the embedded payload")
    func attachedModePayloadSelection() throws {
        let embeddedPayload = Data([0x10, 0x20, 0x30])
        // Attached COSE_Sign1: [protected_bstr, {}, payload_bstr, sig_bstr]
        let coseSign1 = Data([0x84]
            + cborByteString([UInt8](es256ProtectedHeader))
            + [0xA0]
            + cborByteString([UInt8](embeddedPayload))
            + cborByteString([UInt8](repeating: 0xAA, count: 64)))
        let decoded = try CoseSign1Decoder.decode(coseSign1)

        let selected = try PayloadModeValidator.payload(for: .attached, from: decoded)

        #expect(selected == embeddedPayload)
    }

    @Test("Detached mode selects the caller-supplied payload")
    func detachedModePayloadSelection() throws {
        let callerPayload = Data([0x99, 0x88, 0x77])
        // Detached COSE_Sign1: [protected_bstr, {}, null, sig_bstr]
        let coseSign1 = Data([0x84]
            + cborByteString([UInt8](es256ProtectedHeader))
            + [0xA0, 0xF6]
            + cborByteString([UInt8](repeating: 0xAA, count: 64)))
        let decoded = try CoseSign1Decoder.decode(coseSign1)

        let selected = try PayloadModeValidator.payload(
            for: .detached(externalPayload: callerPayload),
            from: decoded
        )

        #expect(selected == callerPayload)
    }

    // MARK: - AC2: A key incompatible with ES256 is rejected

    @Test("An RSA key is rejected with unsupportedAlgorithm")
    func rsaKeyRejected() throws {
        let fixture = try makeSignedFixture()

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]
        var error: Unmanaged<CFError>?
        let rsaPrivate = try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
        let rsaPublic = try #require(SecKeyCopyPublicKey(rsaPrivate))

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: fixture.rawSignature,
                publicKey: rsaPublic
            )
        }
    }

    @Test("A P-384 key is rejected with unsupportedAlgorithm")
    func p384KeyRejected() throws {
        let fixture = try makeSignedFixture()

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 384
        ]
        var error: Unmanaged<CFError>?
        let ecPrivate = try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
        let ecPublic = try #require(SecKeyCopyPublicKey(ecPrivate))

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: fixture.rawSignature,
                publicKey: ecPublic
            )
        }
    }

    @Test("An incompatible key is rejected before the signature encoding is checked")
    func incompatibleKeyTakesPrecedenceOverInvalidSignature() throws {
        let fixture = try makeSignedFixture()

        // Incompatible key + malformed signature must yield unsupportedAlgorithm,
        // proving the key check runs before the signature-encoding check.
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 384
        ]
        var error: Unmanaged<CFError>?
        let ecPrivate = try #require(SecKeyCreateRandomKey(attributes as CFDictionary, &error))
        let ecPublic = try #require(SecKeyCopyPublicKey(ecPrivate))

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: Data(repeating: 0x01, count: 10),
                publicKey: ecPublic
            )
        }
    }

    // MARK: - AC3: A valid ES256 signature verifies successfully

    @Test("A valid ES256 signature verifies successfully")
    func validSignatureSucceeds() throws {
        let fixture = try makeSignedFixture()

        // Should not throw.
        try ES256SignatureVerifier.verify(
            sigStructure: fixture.sigStructure,
            signature: fixture.rawSignature,
            publicKey: fixture.publicKey
        )
    }

    @Test("A valid signature over a larger payload verifies successfully")
    func validSignatureLargerPayload() throws {
        let payload = Data((0..<256).map { UInt8($0 & 0xFF) })
        let fixture = try makeSignedFixture(payload: payload)

        try ES256SignatureVerifier.verify(
            sigStructure: fixture.sigStructure,
            signature: fixture.rawSignature,
            publicKey: fixture.publicKey
        )
    }

    // MARK: - AC4: A signature with an invalid raw encoding is rejected

    @Test("A signature shorter than 64 bytes is rejected")
    func shortSignatureRejected() throws {
        let fixture = try makeSignedFixture()

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: Data(repeating: 0x01, count: 32),
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A signature longer than 64 bytes is rejected")
    func longSignatureRejected() throws {
        let fixture = try makeSignedFixture()

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: Data(repeating: 0x01, count: 72),
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("An empty signature is rejected")
    func emptySignatureRejected() throws {
        let fixture = try makeSignedFixture()

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: Data(),
                publicKey: fixture.publicKey
            )
        }
    }

    // MARK: - AC5: A signature that does not match the verification values is rejected

    @Test("A different 64-byte signature does not authenticate the Sig_structure")
    func differentSignatureRejected() throws {
        let fixture = try makeSignedFixture()
        // A well-formed 64-byte value that was not produced for this structure.
        let bogusSignature = Data(repeating: 0x2B, count: 64)

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: bogusSignature,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A protected header that differs from the signed one is rejected")
    func mismatchedProtectedHeaderRejected() throws {
        let fixture = try makeSignedFixture(protectedHeader: es256ProtectedHeader)

        // Build a Sig_structure with a different protected header — the signature
        // was computed over the original, so verification must fail.
        let tamperedSigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: Data([0xA2, 0x01, 0x26, 0x04, 0x40]),
            payload: fixture.payload
        )

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: tamperedSigStructure,
                signature: fixture.rawSignature,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A payload that differs from the signed one is rejected")
    func mismatchedPayloadRejected() throws {
        let fixture = try makeSignedFixture(payload: Data([0x01, 0x02, 0x03]))

        let tamperedSigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: fixture.protectedHeader,
            payload: Data([0x01, 0x02, 0x04])
        )

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: tamperedSigStructure,
                signature: fixture.rawSignature,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A public key that does not match the signing key is rejected")
    func mismatchedKeyRejected() throws {
        let fixture = try makeSignedFixture()
        let otherKey = try secKey(from: P256.Signing.PrivateKey().publicKey)

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try ES256SignatureVerifier.verify(
                sigStructure: fixture.sigStructure,
                signature: fixture.rawSignature,
                publicKey: otherKey
            )
        }
    }
}
