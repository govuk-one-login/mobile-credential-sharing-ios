@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import Testing
import X509

/// C8 — verify detached ReaderAuth. Composes C2 → (detached payload) → C4 → C5 → C6 → C3 behind
/// the public `verifyDetached(coseSign1Bytes:detachedPayload:trustedRoot:)`.
///
/// AC1 proves the complete detached success path returns the trusted reader leaf without copying
/// the caller-owned payload. AC2 proves that a failure from any composed verification stage
/// propagates as the expected typed failure and yields no partial result.
@Suite("C8 verify detached ReaderAuth")
struct VerifyDetachedReaderAuthTests {

    private let sut = CoseVerification()

    // MARK: - AC1: A valid ReaderAuth value returns the trusted leaf without copying the payload

    @Test("Returns the verified reader leaf and does not copy the caller-owned detached payload")
    func validReaderAuthReturnsLeafWithoutPayload() async throws {
        let fixture = try DetachedReaderAuthFixtures.make()

        let result = try await sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            trustedRoot: fixture.trustedRoot
        )

        // The result never duplicates or returns the detached payload.
        #expect(result.payload == nil)

        // The returned leaf is the signing reader leaf carried in the x5chain.
        var serializer = DER.Serializer()
        try serializer.serialize(result.leafCertificate)
        #expect(Data(serializer.serializedBytes) == fixture.leafDer)
    }

    // MARK: - AC2: A failed stage returns no partial result (one vector per boundary)

    @Test("C2 boundary: a COSE_Sign1 that is not four elements throws malformedCoseSign1")
    func c2MalformedThrows() async throws {
        let fixture = try DetachedReaderAuthFixtures.make()
        // Truncate to a 3-element array header, keeping otherwise plausible bytes.
        var bytes = [UInt8](fixture.coseSign1Bytes)
        bytes[0] = 0x83 // array(3)

        await #expect(throws: CoseVerificationFailure.malformedCoseSign1) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: Data(bytes),
                detachedPayload: fixture.detachedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    @Test("C2 boundary: a protected algorithm other than ES256 throws unsupportedAlgorithm")
    func c2UnsupportedAlgorithmThrows() async throws {
        // {1: -8} (EdDSA) instead of {1: -7} (ES256): A1 01 27.
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.protectedHeader = Data([0xA1, 0x01, 0x27])
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    @Test("C4 boundary: no x5chain in either header throws missingX5Chain")
    func c4MissingX5ChainThrows() async throws {
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.omitX5Chain = true
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.missingX5Chain) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    @Test("C5 boundary: a path that does not terminate at the caller reader root throws untrustedCertificate")
    func c5UntrustedCertificateThrows() async throws {
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.useWrongTrustedRoot = true
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    @Test("C6 boundary: a reader leaf without the ReaderAuth EKU throws certificateProfileViolation")
    func c6CertificateProfileViolationThrows() async throws {
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.omitReaderAuthEKU = true
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        // Confirm the specific typed failure and that no result escapes.
        do {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
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
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.tamperSignature = true
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        await #expect(throws: CoseVerificationFailure.invalidSignature) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: fixture.detachedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    // MARK: - DoD: the signature is bound to the exact caller-owned detached payload

    @Test("Changing the caller-owned detached payload invalidates the signature")
    func mutatingDetachedPayloadInvalidatesSignature() async throws {
        // The fixture signs over `detachedPayload`. Asking the verifier about different bytes must
        // fail: this proves C8 passes the caller-supplied payload (not an embedded/re-encoded copy)
        // through C2 selection to C3, and that the payload is never substituted internally.
        let fixture = try DetachedReaderAuthFixtures.make()
        let tamperedPayload = fixture.detachedPayload + Data([0x00])

        await #expect(throws: CoseVerificationFailure.invalidSignature) {
            _ = try await sut.verifyDetached(
                coseSign1Bytes: fixture.coseSign1Bytes,
                detachedPayload: tamperedPayload,
                trustedRoot: fixture.trustedRoot
            )
        }
    }

    @Test("The verified signature covers the exact caller-supplied detached payload")
    func signatureIsBoundToCallerDetachedPayload() async throws {
        // A distinctive detached payload makes the round-trip explicit: the success path signs over
        // and verifies exactly these bytes, and the result still returns nil (no payload copy).
        var overrides = DetachedReaderAuthFixtures.Overrides()
        overrides.detachedPayload = Data([0xCA, 0xFE, 0xBA, 0xBE, 0x00, 0x11, 0x22])
        let fixture = try DetachedReaderAuthFixtures.make(overrides)

        let result = try await sut.verifyDetached(
            coseSign1Bytes: fixture.coseSign1Bytes,
            detachedPayload: fixture.detachedPayload,
            trustedRoot: fixture.trustedRoot
        )

        #expect(result.payload == nil)
    }
}
