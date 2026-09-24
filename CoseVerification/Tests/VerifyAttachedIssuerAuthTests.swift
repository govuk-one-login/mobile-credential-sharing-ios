@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import Testing
import X509

/// C7 — verify attached IssuerAuth. Composes C2 → C4 → C5 → C6 → C3 behind the public
/// `verifyAttached(coseSign1Bytes:trustedRoot:)`.
///
/// AC1 proves the complete success path. AC2 proves that a failure from any composed verification
/// stage propagates as the expected typed failure and yields no partial result.
@Suite("C7 verify attached IssuerAuth")
struct VerifyAttachedIssuerAuthTests {

    private let sut = CoseVerification()

    // MARK: - AC1: A valid IssuerAuth value returns the trusted leaf and payload

    @Test("Returns the verified leaf and the exact attached payload")
    func validIssuerAuthReturnsLeafAndPayload() async throws {
        let fixture = try AttachedIssuerAuthFixtures.make()

        let result = try await sut.verifyAttached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            trustedRoot: fixture.trustedRoot
        )

        // The exact attached payload bytes are returned, byte-for-byte.
        #expect(result.payload == fixture.payload)

        // The returned leaf is the signing leaf carried in the x5chain.
        var serializer = DER.Serializer()
        try serializer.serialize(result.leafCertificate)
        #expect(Data(serializer.serializedBytes) == fixture.leafDer)
    }

    // MARK: - AC2: A failed stage returns no partial result (one vector per boundary)

    @Test("C2 boundary: a COSE_Sign1 that is not four elements throws malformedCoseSign1")
    func c2MalformedThrows() async throws {
        let fixture = try AttachedIssuerAuthFixtures.make()
        // Truncate to a 3-element array header, keeping otherwise plausible bytes.
        var bytes = [UInt8](fixture.coseSign1Bytes)
        bytes[0] = 0x83 // array(3)

        await #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            try await sut.verifyAttached(coseSign1Bytes: Data(bytes), trustedRoot: fixture.trustedRoot)
        }
    }

    @Test("C2 boundary: a protected algorithm other than ES256 throws unsupportedAlgorithm")
    func c2UnsupportedAlgorithmThrows() async throws {
        // {1: -8} (EdDSA) instead of {1: -7} (ES256): A1 01 27.
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.protectedHeader = Data([0xA1, 0x01, 0x27])
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await sut.verifyAttached(coseSign1Bytes: fixture.coseSign1Bytes, trustedRoot: fixture.trustedRoot)
        }
    }

    @Test("C4 boundary: no x5chain in either header throws missingX5Chain")
    func c4MissingX5ChainThrows() async throws {
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.omitX5Chain = true
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.missingX5Chain) {
            try await sut.verifyAttached(coseSign1Bytes: fixture.coseSign1Bytes, trustedRoot: fixture.trustedRoot)
        }
    }

    @Test("C5 boundary: a path that does not terminate at the caller root throws untrustedCertificate")
    func c5UntrustedCertificateThrows() async throws {
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.useWrongTrustedRoot = true
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await sut.verifyAttached(coseSign1Bytes: fixture.coseSign1Bytes, trustedRoot: fixture.trustedRoot)
        }
    }

    @Test("C6 boundary: an issuer leaf without the IssuerAuth EKU throws certificateProfileViolation")
    func c6CertificateProfileViolationThrows() async throws {
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.omitIssuerAuthEKU = true
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        await #expect(throws: (any Error).self) {
            try await sut.verifyAttached(coseSign1Bytes: fixture.coseSign1Bytes, trustedRoot: fixture.trustedRoot)
        }

        // Confirm the specific typed failure and that no result escapes.
        do {
            _ = try await sut.verifyAttached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                trustedRoot: fixture.trustedRoot
            )
            Issue.record("Expected a certificateProfileViolation failure")
        } catch let failure as CoseVerificationFailure {
            guard case .certificateProfileViolation = failure else {
                Issue.record("Expected certificateProfileViolation, got \(failure)")
                return
            }
        }
    }

    @Test("C3 boundary: a signature that does not authenticate the payload throws invalidSignature")
    func c3InvalidSignatureThrows() async throws {
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.tamperSignature = true
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.invalidSignature) {
            try await sut.verifyAttached(coseSign1Bytes: fixture.coseSign1Bytes, trustedRoot: fixture.trustedRoot)
        }
    }

    // MARK: - DoD: C7 passes the C2-selected payload and C6-verified leaf key to C3

    @Test("The verified signature covers the exact embedded payload")
    func signatureIsBoundToEmbeddedPayload() async throws {
        // The success path signs over, embeds, and returns the same payload. If C7 passed any other
        // payload to C3 (e.g. a re-encoded copy), signature verification would fail. Using a
        // distinctive payload makes the round-trip explicit.
        var overrides = AttachedIssuerAuthFixtures.Overrides()
        overrides.payload = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x11, 0x22])
        let fixture = try AttachedIssuerAuthFixtures.make(overrides)

        let result = try await sut.verifyAttached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            trustedRoot: fixture.trustedRoot
        )

        #expect(result.payload == Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x11, 0x22]))
    }
}
