@testable import CoseVerification
import Foundation
import Testing
@_spi(FixedExpiryValidationTime) import X509

@Suite("Trusted roots path validation")
struct TrustedRootsPathValidatorTests {
    private typealias Fixtures = CertificatePathFixtures

    // MARK: - AC1: A chain any supplied root validates is trusted (root A listed first)

    @Test("A chain valid against the first supplied root returns C5's validated path unchanged")
    func chainTrustedByFirstRoot() async throws {
        let path = try await TrustedRootsPathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRoots: [Fixtures.root256, Fixtures.wrongRoot256],
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(path == [Fixtures.leaf256])
    }

    // MARK: - AC2: A chain valid only against a later anchor still verifies

    @Test("A chain valid only against a later root passes regardless of root order", arguments: [
        [CertificatePathFixtures.wrongRoot256, CertificatePathFixtures.root256],
        [CertificatePathFixtures.root256, CertificatePathFixtures.wrongRoot256]
    ])
    func chainTrustedByLaterRootOrderIndependent(roots: [Data]) async throws {
        // leaf256 is trusted only by root256; wrongRoot256 returns untrustedCertificate first.
        let path = try await TrustedRootsPathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRoots: roots,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(path == [Fixtures.leaf256])
    }

    // MARK: - AC3: A chain that embeds any supplied root is rejected before validation

    @Test("A chain containing a supplied root is rejected, and reversing the set preserves it",
          arguments: [
        [CertificatePathFixtures.root256, CertificatePathFixtures.wrongRoot256],
        [CertificatePathFixtures.wrongRoot256, CertificatePathFixtures.root256]
    ])
    func chainContainingSuppliedRootRejected(roots: [Data]) async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.leaf256, Fixtures.root256],
                trustedRoots: roots,
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - AC4: A chain trusted by no supplied anchor fails with untrustedCertificate

    @Test("A chain trusted by none of the supplied roots fails with untrustedCertificate")
    func chainFailsWhenNoRootTrustsIt() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRoots: [Fixtures.wrongRoot256, Fixtures.root384],
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - Requirement 1: An empty root list is rejected before any C5 call

    @Test("An empty trusted-roots list fails with untrustedCertificate")
    func emptyRootListRejected() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRoots: [],
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - Requirement 6: Any other C5 failure propagates unchanged and stops attempts

    @Test("An unsupported-algorithm failure propagates unchanged rather than trying later roots")
    func otherFailurePropagates() async {
        // rsaLeaf256 fails C5 with unsupportedAlgorithm; C10 propagates it rather than continuing.
        await #expect(throws: CoseVerificationFailure.unsupportedAlgorithm) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.rsaLeaf256],
                trustedRoots: [Fixtures.root256, Fixtures.wrongRoot256],
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - Helpers

    /// Builds a fixed-time expiry-policy provider so time-dependent behaviour is deterministic.
    private static func expiry(at time: Date) -> CertificatePathValidator.ExpiryPolicyProvider {
        { RFC5280Policy(fixedExpiryValidationTime: time) }
    }
}
