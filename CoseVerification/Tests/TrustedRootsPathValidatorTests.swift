@testable import CoseVerification
import Foundation
import Testing
@_spi(FixedExpiryValidationTime) import X509

@Suite("Trusted roots path validation")
struct TrustedRootsPathValidatorTests {
    private typealias Fixtures = CertificatePathFixtures

    // MARK: - AC1: A chain passes when a supplied root trusts it (order-independent)

    @Test("A chain valid only against root B passes regardless of root order", arguments: [
        [CertificatePathFixtures.wrongRoot256, CertificatePathFixtures.root256],
        [CertificatePathFixtures.root256, CertificatePathFixtures.wrongRoot256]
    ])
    func chainPassesRegardlessOfRootOrder(roots: [Data]) async throws {
        // leaf256 is trusted only by root256; wrongRoot256 does not trust it.
        let path = try await TrustedRootsPathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRoots: roots,
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(path == [Fixtures.leaf256])
    }

    // MARK: - AC2: Duplicate root certificates are checked once

    @Test("Byte-identical duplicate roots do not change the public untrustedCertificate result")
    func duplicateRootsCollapseToOneResult() async {
        // No supplied root trusts leaf256; duplicates collapse to one result.
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.leaf256],
                trustedRoots: [Fixtures.wrongRoot256, Fixtures.wrongRoot256, Fixtures.wrongRoot256],
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    @Test("Moving duplicates within the list does not change a successful result")
    func duplicatesDoNotAffectSuccess() async throws {
        // root256 trusts leaf256; duplicates and an untrusting root are interleaved.
        let path = try await TrustedRootsPathValidator.validate(
            certificateChain: [Fixtures.leaf256],
            trustedRoots: [Fixtures.wrongRoot256, Fixtures.root256, Fixtures.root256],
            expiryPolicy: Self.expiry(at: Fixtures.validNow)
        )
        #expect(path == [Fixtures.leaf256])
    }

    // MARK: - AC3: A chain fails when no supplied root trusts it

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

    // MARK: - Requirement 3: A chain containing a supplied root is rejected before C5

    @Test("A chain that contains a supplied root fails with untrustedCertificate")
    func chainContainingSuppliedRootRejected() async {
        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try await TrustedRootsPathValidator.validate(
                certificateChain: [Fixtures.leaf256, Fixtures.root256],
                trustedRoots: [Fixtures.root256],
                expiryPolicy: Self.expiry(at: Fixtures.validNow)
            )
        }
    }

    // MARK: - Requirement 7: Any other C5 failure propagates unchanged and stops attempts

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
