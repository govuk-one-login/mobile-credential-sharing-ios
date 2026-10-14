@testable import CoseVerification
import Crypto
import Foundation
import SwiftASN1
import Testing
import X509

/// Unit tests for ``CertificateExpiryPolicy`` (DCMAW-24067, C5.1).
///
/// These drive the per-certificate ``CertificateExpiryPolicy/evaluate(_:at:)`` seam directly, since
/// `UnverifiedCertificateChain` cannot be constructed outside the X509 module. They reuse the shared
/// ``CertificatePathFixtures`` certificates and fixed instants, pinning the AC2–AC5 outcomes and
/// diagnostic reasons.
@Suite("CertificateExpiryPolicy")
struct CertificateExpiryPolicyTests {
    private typealias Fixtures = CertificatePathFixtures

    // MARK: - AC2: not yet valid

    @Test("A certificate evaluated before its notBefore fails as not yet valid")
    func notYetValid() throws {
        let leaf = try Fixtures.certificate(Fixtures.leaf256)

        let result = CertificateExpiryPolicy.evaluate(leaf, at: Fixtures.beforeNotBefore)

        #expect(reason(result)?.contains("is not yet valid") == true)
    }

    // MARK: - AC3: expired

    @Test("A certificate evaluated after its notAfter fails as expired")
    func expired() throws {
        let leaf = try Fixtures.certificate(Fixtures.leaf256)

        let result = CertificateExpiryPolicy.evaluate(leaf, at: Fixtures.afterNotAfter)

        #expect(reason(result)?.contains("has expired") == true)
    }

    // MARK: - AC4: inverted validity

    @Test("A certificate whose notAfter precedes notBefore fails as invalid expiry")
    func invertedValidity() throws {
        // No shared fixture so this is the single case that must build a certificate with
        // notAfter < notBefore directly.
        let notBefore = Date(timeIntervalSince1970: 1_900_000_000)
        let notAfter = Date(timeIntervalSince1970: 1_800_000_000)
        let cert = try makeCertificate(notValidBefore: notBefore, notValidAfter: notAfter)

        let result = CertificateExpiryPolicy.evaluate(cert, at: Fixtures.validNow)

        #expect(reason(result)?.contains("has invalid expiry") == true)
    }

    // MARK: - AC5: valid

    @Test("A certificate evaluated within its validity interval meets the policy")
    func valid() throws {
        let leaf = try Fixtures.certificate(Fixtures.leaf256)

        guard case .meetsPolicy = CertificateExpiryPolicy.evaluate(leaf, at: Fixtures.validNow) else {
            Issue.record("Expected .meetsPolicy for a certificate valid at validNow")
            return
        }
    }

    // MARK: - Helpers

    private func reason(_ result: PolicyEvaluationResult) -> String? {
        if case .failsToMeetPolicy(let reason) = result { return reason.description }
        return nil
    }

    /// Builds a self-signed P-256 certificate with the given validity window. Only used for the
    /// inverted-validity case (AC4), which no shared fixture can represent.
    private func makeCertificate(notValidBefore: Date, notValidAfter: Date) throws -> Certificate {
        let key = P256.Signing.PrivateKey()
        let name = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Expiry Test")
        }
        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: Certificate.PublicKey(key.publicKey),
            notValidBefore: notValidBefore,
            notValidAfter: notValidAfter,
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: try Certificate.Extensions {},
            issuerPrivateKey: Certificate.PrivateKey(key)
        )
    }
}
