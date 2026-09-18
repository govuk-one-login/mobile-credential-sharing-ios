@testable import CoseVerification
import CryptoKit
import Foundation
import Security
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
}
