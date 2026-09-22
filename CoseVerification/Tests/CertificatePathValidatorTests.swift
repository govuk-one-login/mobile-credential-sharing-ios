@testable import CoseVerification
import Foundation
import Testing
@_spi(FixedExpiryValidationTime) import X509

@Suite("Certificate path validation")
struct CertificatePathValidatorTests {
    private typealias Fixtures = CertificatePathFixtures

    // MARK: - AC1: A valid candidate chain exposes the complete validated path

    @Test("A valid P-256 leaf anchored to its root returns the leaf-first path")
    func validP256DirectLeaf() async throws {
        let result = try await CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRootDer: Fixtures.root256,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(result.path == Self.certificates([Fixtures.leaf256]))
    }

    @Test("A valid P-256 leaf+intermediate path anchored to its root is returned in order")
    func validP256IntermediatePath() async throws {
        let chain = [Fixtures.leafInt256, Fixtures.int256]
        let result = try await CertificatePathValidator.validate(
            certificateChain: chain,
            trustedRootDer: Fixtures.root256,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        // The validated path is leaf-first and excludes the root.
        #expect(result.path == Self.certificates(chain))
    }

    @Test("A valid P-384 leaf anchored to its root returns the path")
    func validP384DirectLeaf() async throws {
        let result = try await CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf384],
            trustedRootDer: Fixtures.root384,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(result.path == Self.certificates([Fixtures.leaf384]))
    }

    @Test("A P-384 issuer signing a leaf with ECDSA-SHA256 validates (independent curve/hash)")
    func crossCurveHashPairing() async throws {
        // The signature-algorithm and issuer-curve allow-lists are independent: a P-384 issuer key
        // may sign with ECDSA-SHA256. This must not be rejected.
        let result = try await CertificatePathValidator.validate(
            certificateChain: [Fixtures.crossPairingLeaf],
            trustedRootDer: Fixtures.crossPairingRoot,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(result.path == Self.certificates([Fixtures.crossPairingLeaf]))
    }

    @Test("An expired trusted root causes the chain to fail (root validity IS checked)")
    func expiredRootRejected() async {
        // shortLivedRoot expired 2026-09-10; at validNow (2027) it is expired. Because the verifier
        // appends the trusted root to the chain and the injected RFC5280Policy time-checks the whole
        // chain, the otherwise-live leaf it signed no longer validates.
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leafUnderShortRoot],
                trustedRootDer: Fixtures.shortLivedRoot,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - AC2: An invalid or untrusted candidate chain is rejected (untrustedCertificate)

    @Test("A certificate whose notBefore is in the future fails with untrustedCertificate")
    func notYetValid() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.beforeNotBefore)
            )
        }
    }

    @Test("A certificate whose notAfter is in the past fails with untrustedCertificate")
    func expired() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.afterNotAfter)
            )
        }
    }

    @Test("A leaf anchored to the wrong root fails with untrustedCertificate")
    func wrongRoot() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.wrongRoot256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A leaf with a valid structure but a tampered signature fails with untrustedCertificate")
    func tamperedSignature() async {
        // The tampered leaf shares leaf256's tbsCertificate, issuer, and subject, so its name
        // linkage to root256 holds and only the ECDSA signature is invalid. The verifier therefore
        // rejects it specifically on signature verification.
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.tamperedSignature256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("An incomplete chain (missing intermediate) fails with untrustedCertificate")
    func incompleteChain() async {
        // leafInt256 is issued by int256, not directly by root256; omitting int256 breaks linkage.
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leafInt256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A reordered chain is accepted (the verifier builds the path)")
    func reorderedChain() async throws {
        // The verifier builds the path and is order-independent, so a reordered candidate list still
        // validates.
        let result = try await CertificatePathValidator.validate(
            certificateChain: [Fixtures.int256, Fixtures.leafInt256],
            trustedRootDer: Fixtures.root256,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(result.path == Self.certificates([Fixtures.int256, Fixtures.leafInt256]))
    }

    @Test("The root included in the candidate chain fails with untrustedCertificate")
    func rootInChain() async {
        // The candidate chain must carry only the leaf and intermediates; including the
        // caller-provided root is rejected.
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256, Fixtures.root256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A duplicated certificate in the chain is accepted")
    func duplicatedCertificate() async throws {
        // The verifier builds the path and tolerates a duplicated candidate, collapsing the repeat
        // rather than rejecting it.
        let result = try await CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf256, Fixtures.leaf256],
            trustedRootDer: Fixtures.root256,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(result.path == Self.certificates([Fixtures.leaf256, Fixtures.leaf256]))
    }

    @Test("A leaf with an unrecognised critical extension fails with untrustedCertificate")
    func unknownCriticalExtension() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.critLeaf256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A leaf with a duplicate extension OID fails with untrustedCertificate")
    func duplicateExtensionOid() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.dupExtension256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("An empty candidate chain fails with untrustedCertificate")
    func emptyChain() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A structurally truncated certificate fails with untrustedCertificate")
    func truncatedCertificate() async {
        // Drop the final 40 bytes so the DER can no longer parse as a complete Certificate.
        let truncated = Fixtures.leaf256.dropLast(40)
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [Data(truncated)],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("Trailing bytes after the certificate fail with untrustedCertificate")
    func trailingBytes() async {
        let withTrailer = Fixtures.leaf256 + Data([0x00, 0x01, 0x02])
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await CertificatePathValidator.validate(
                certificateChain: [withTrailer],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - AC3: A certificate outside the algorithm/key allow-list is rejected distinctly

    @Test("An RSA leaf fails with unsupportedAlgorithm")
    func rsaKeyRejected() async {
        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.rsaLeaf256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A P-521 leaf (unsupported curve) fails with unsupportedAlgorithm")
    func p521CurveRejected() async {
        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.p521Leaf256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A leaf signed with ECDSA-SHA1 fails with unsupportedAlgorithm")
    func disallowedSignatureAlgorithm() async {
        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.sha1Leaf],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("A leaf whose tbsCertificate.signature differs from signatureAlgorithm fails with unsupportedAlgorithm")
    func tbsSignatureMismatch() async {
        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await CertificatePathValidator.validate(
                certificateChain: [Fixtures.tbsSigMismatch256],
                trustedRootDer: Fixtures.root256,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - Helpers

    /// Builds a fixed-time expiry-policy provider so time-dependent behaviour is deterministic.
    /// Production uses the default current-time policy; tests pin the validation instant here.
    private static func expiry(at time: Date) -> CertificatePathValidator.ExpiryPolicyProvider {
        { RFC5280Policy(fixedExpiryValidationTime: time) }
    }

    /// Parses DER fixtures into `Certificate` values so the leaf-first path returned by the
    /// validator (now `[Certificate]`) can be compared against the expected fixtures.
    private static func certificates(_ ders: [Data]) -> [Certificate] {
        ders.map { try! Certificate(derEncoded: Array($0)) } // swiftlint:disable:this force_try
    }
}
