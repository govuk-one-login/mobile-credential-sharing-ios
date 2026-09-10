@testable import CoseVerification
import Foundation
import Testing

@Suite("Certificate path validation")
struct CertificatePathValidatorTests {

    private typealias Fixtures = CertificatePathFixtures

    // MARK: - AC1: A valid candidate chain exposes the complete validated path

    @Test("A valid P-256 leaf anchored to its root returns the leaf-first path")
    func validP256DirectLeaf() throws {
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRootDer: Fixtures.root256,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.leaf256])
    }

    @Test("A valid P-256 leaf+intermediate path anchored to its root is returned in order")
    func validP256IntermediatePath() throws {
        let chain = [Fixtures.leafInt256, Fixtures.int256]
        let path = try CertificatePathValidator.validate(
            certificateChain: chain,
            trustedRootDer: Fixtures.root256,
            now: Fixtures.validNow
        )
        // The validated path is leaf-first and excludes the root.
        #expect(path == chain)
    }

    @Test("A valid P-384 leaf anchored to its root returns the path")
    func validP384DirectLeaf() throws {
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf384],
            trustedRootDer: Fixtures.root384,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.leaf384])
    }

    @Test("A P-384 issuer signing a leaf with ECDSA-SHA256 validates (independent curve/hash)")
    func crossCurveHashPairing() throws {
        // The signature-algorithm and issuer-curve allow-lists are independent: a P-384 issuer key
        // may sign with ECDSA-SHA256. This must not be rejected.
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.crossPairingLeaf],
            trustedRootDer: Fixtures.crossPairingRoot,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.crossPairingLeaf])
    }

    @Test("The trusted root's own validity period is not checked (expired root still anchors)")
    func rootValidityExempt() throws {
        // shortLivedRoot expired 2026-09-10; at validNow (2027) it is expired, but the live leaf it
        // signed must still validate because C5 does not check the root's own validity.
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.leafUnderShortRoot],
            trustedRootDer: Fixtures.shortLivedRoot,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.leafUnderShortRoot])
    }

    // MARK: - AC2: An invalid or untrusted candidate chain is rejected (untrustedCertificate)

    @Test("A certificate whose notBefore is in the future fails with untrustedCertificate")
    func notYetValid() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.beforeNotBefore
            )
        }
    }

    @Test("A certificate whose notAfter is in the past fails with untrustedCertificate")
    func expired() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.afterNotAfter
            )
        }
    }

    @Test("A leaf anchored to the wrong root fails with untrustedCertificate")
    func wrongRoot() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRootDer: Fixtures.wrongRoot256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A leaf with a valid structure but a tampered signature fails with untrustedCertificate")
    func tamperedSignature() {
        // The tampered leaf shares leaf256's tbsCertificate, issuer, and subject, so its name
        // linkage to root256 holds and only the ECDSA signature is invalid. SecTrust therefore
        // rejects it specifically on signature verification.
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.tamperedSignature256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("An incomplete chain (missing intermediate) fails with untrustedCertificate")
    func incompleteChain() {
        // leafInt256 is issued by int256, not directly by root256; omitting int256 breaks linkage.
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.leafInt256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A reordered chain is accepted (SecTrust builds the path)")
    func reorderedChain() throws {
        // SecTrust builds the path and is order-independent, so a reordered candidate list still
        // validates.
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.int256, Fixtures.leafInt256],
            trustedRootDer: Fixtures.root256,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.int256, Fixtures.leafInt256])
    }

    @Test("The root included in the candidate chain fails with untrustedCertificate")
    func rootInChain() {
        // The candidate chain must carry only the leaf and intermediates; including the
        // caller-provided root is rejected.
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.leaf256, Fixtures.root256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A duplicated certificate in the chain is accepted")
    func duplicatedCertificate() throws {
        // SecTrust builds the path and tolerates a duplicated candidate, collapsing the repeat
        // rather than rejecting it.
        let path = try CertificatePathValidator.validate(
            certificateChain: [Fixtures.leaf256, Fixtures.leaf256],
            trustedRootDer: Fixtures.root256,
            now: Fixtures.validNow
        )
        #expect(path == [Fixtures.leaf256, Fixtures.leaf256])
    }

    @Test("A leaf with an unrecognised critical extension fails with untrustedCertificate")
    func unknownCriticalExtension() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.critLeaf256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A leaf with a duplicate extension OID fails with untrustedCertificate")
    func duplicateExtensionOid() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.dupExtension256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("An empty candidate chain fails with untrustedCertificate")
    func emptyChain() {
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A structurally truncated certificate fails with untrustedCertificate")
    func truncatedCertificate() {
        // Drop the final 40 bytes so the DER can no longer parse as a complete Certificate.
        let truncated = Fixtures.leaf256.dropLast(40)
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [Data(truncated)],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("Trailing bytes after the certificate fail with untrustedCertificate")
    func trailingBytes() {
        let withTrailer = Fixtures.leaf256 + Data([0x00, 0x01, 0x02])
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try CertificatePathValidator.validate(
                certificateChain: [withTrailer],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    // MARK: - AC3: A certificate outside the algorithm/key allow-list is rejected distinctly

    @Test("An RSA leaf fails with unsupportedAlgorithm")
    func rsaKeyRejected() {
        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.rsaLeaf256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A P-521 leaf (unsupported curve) fails with unsupportedAlgorithm")
    func p521CurveRejected() {
        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.p521Leaf256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A leaf signed with ECDSA-SHA1 fails with unsupportedAlgorithm")
    func disallowedSignatureAlgorithm() {
        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.sha1Leaf],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }

    @Test("A leaf whose tbsCertificate.signature differs from signatureAlgorithm fails with unsupportedAlgorithm")
    func tbsSignatureMismatch() {
        #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try CertificatePathValidator.validate(
                certificateChain: [Fixtures.tbsSigMismatch256],
                trustedRootDer: Fixtures.root256,
                now: Fixtures.validNow
            )
        }
    }
}
