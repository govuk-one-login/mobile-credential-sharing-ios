@testable import CoseVerification
import CryptoKit
import Foundation
import SwiftCBOR
import Testing

@Suite("Direct-key detached DeviceSignature")
struct DirectKeyDeviceSignatureTests {

    private let sut = CoseVerification()

    /// Protected-header bytes: `alg = -7` plus optional extra pairs.
    private func protectedHeaderBytes(extra: [(CBOR, CBOR)] = []) -> Data {
        let algPair: (CBOR, CBOR) = (.unsignedInt(1), .negativeInt(6))
        let map = Dictionary([algPair] + extra, uniquingKeysWith: { first, _ in first })
        return Data(CBOR.map(map).encode())
    }

    /// Unprotected-header map CBOR bytes from label/value pairs.
    private func unprotectedHeaderBytes(_ pairs: [(CBOR, CBOR)]) -> [UInt8] {
        let map = Dictionary(pairs, uniquingKeysWith: { first, _ in first })
        return [UInt8](Data(CBOR.map(map).encode()))
    }

    // MARK: - AC1: A valid direct-key detached signature succeeds

    @Test("A valid detached signature verifies and returns no material")
    func validSignatureSucceeds() throws {
        let fixture = try makeDetachedCoseSign1()

        try sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            publicKey: fixture.publicKey
        )
    }

    @Test("Verification uses the exact caller-supplied detached payload bytes")
    func exactPayloadReachesVerification() throws {
        let payload = Data((0..<200).map { UInt8($0 & 0xFF) })
        let fixture = try makeDetachedCoseSign1(detachedPayload: payload)

        try sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: payload,
            publicKey: fixture.publicKey
        )
    }

    @Test("A caller payload that differs from the signed one fails with invalidSignature")
    func differentCallerPayloadFails() throws {
        let fixture = try makeDetachedCoseSign1(detachedPayload: Data([0x01, 0x02, 0x03]))

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: Data([0x01, 0x02, 0x04]),
                publicKey: fixture.publicKey
            )
        }
    }

    // MARK: - AC2: Certificate-header parameters do not affect direct-key verification

    @Test("Verification succeeds when certificate-header parameters are absent")
    func certificateHeadersAbsentSucceeds() throws {
        let fixture = try makeDetachedCoseSign1()

        try sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            publicKey: fixture.publicKey
        )
    }

    @Test("Verification succeeds with protected x5bag+x5t and unprotected x5chain present")
    func certificateHeadersPresentStateOneSucceeds() throws {
        let protected = protectedHeaderBytes(extra: [
            (x5bagLabel(), x5chainSingle(CertificateFixtures.leafDER)),
            (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))
        ])
        let unprotected = unprotectedHeaderBytes([
            (x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))
        ])

        // Sign over the same protected bytes the signature must cover.
        let fixture = try makeDetachedCoseSign1(
            protectedHeader: protected,
            unprotectedHeaderBytes: unprotected,
            protectedHeaderForSigStructure: protected
        )

        try sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            publicKey: fixture.publicKey
        )
    }

    @Test("Verification succeeds with unprotected x5bag+x5t and protected x5chain present")
    func certificateHeadersPresentStateTwoSucceeds() throws {
        // A certificate-backed op would reject protected x5chain; the direct-key op ignores it.
        let protected = protectedHeaderBytes(extra: [
            (x5chainLabel(), x5chainSingle(CertificateFixtures.leafDER))
        ])
        let unprotected = unprotectedHeaderBytes([
            (x5bagLabel(), x5chainSingle(CertificateFixtures.leafDER)),
            (x5tLabel(), x5tValue(hash: CertificateFixtures.leafSHA256))
        ])

        let fixture = try makeDetachedCoseSign1(
            protectedHeader: protected,
            unprotectedHeaderBytes: unprotected,
            protectedHeaderForSigStructure: protected
        )

        try sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            publicKey: fixture.publicKey
        )
    }
    
    // MARK: - AC3: Direct-key verification propagates its typed failures

    @Test("A COSE_Sign1 that is not a four-element array fails with malformedCoseSign1")
    func nonFourElementArrayFails() throws {
        // Three-element array: [protected, unprotected, null].
        let threeElement = Data([0x83]
            + cborByteString([UInt8](es256ProtectedHeader))
            + [0xA0, 0xF6])

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try sut.verifyDetached(
                coseSign1Bytes: threeElement,
                detachedPayload: Data([0xDE, 0xAD, 0xBE, 0xEF]),
                publicKey: P256.Signing.PrivateKey().publicKey
            )
        }
    }

    @Test("A protected algorithm other than ES256 fails with unsupportedAlgorithm")
    func nonES256AlgorithmFails() throws {
        // {1: -35} ES384, -35 encodes as negativeInt(34).
        let alg384: (CBOR, CBOR) = (.unsignedInt(1), .negativeInt(34))
        let protected = Data(CBOR.map(Dictionary([alg384], uniquingKeysWith: { first, _ in first })).encode())

        let fixture = try makeDetachedCoseSign1(
            protectedHeader: protected,
            protectedHeaderForSigStructure: protected
        )

        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A signature that is not a 64-byte raw r||s value fails with invalidSignature")
    func nonRawSignatureFails() throws {
        let fixture = try makeDetachedCoseSign1(
            signatureOverride: Data(repeating: 0x01, count: 70)
        )

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("A 64-byte signature that does not authenticate the payload fails with invalidSignature")
    func nonVerifyingSignatureFails() throws {
        let fixture = try makeDetachedCoseSign1(
            signatureOverride: Data(repeating: 0x2B, count: 64)
        )

        #expect(throws: CoseVerificationFailure.invalidSignature) {
            try sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                publicKey: fixture.publicKey
            )
        }
    }

    @Test("An attached (non-null) payload fails with malformedCoseSign1 in detached mode")
    func attachedPayloadRejectedInDetachedMode() throws {
        let attached = cborCoseSign1(
            protectedHeader: [UInt8](es256ProtectedHeader),
            payload: .attached([0x10, 0x20, 0x30]),
            signature: [UInt8](repeating: 0xAA, count: 64)
        )

        #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try sut.verifyDetached(
                coseSign1Bytes: attached,
                detachedPayload: Data([0xDE, 0xAD, 0xBE, 0xEF]),
                publicKey: P256.Signing.PrivateKey().publicKey
            )
        }
    }
}
