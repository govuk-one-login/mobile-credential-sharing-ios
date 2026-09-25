@testable import CoseVerification
import Foundation
import SwiftASN1
import Testing
import X509

/// Conformance tests for ``CertificateProfileValidator`` (C6), covering DCMAW-22160 AC1–AC4.
///
/// Fixtures are built in-process by ``ProfileCertificateFactory`` so each negative case flips a
/// single profile attribute against an otherwise-compliant hierarchy. The ReaderAuth NameConstraints
/// check uses the local ``PrefixNameConstraintsPolicy``, which has no time dependency.
@Suite("Certificate profile validation (C6)")
struct CertificateProfileValidatorTests {
    private typealias Factory = ProfileCertificateFactory

    // MARK: - AC1: a valid IssuerAuth profile approves the path

    @Test("A fully compliant IssuerAuth path is approved and returns the leaf public key")
    func validIssuerAuthApproved() async throws {
        let specs = Factory.issuerAuthSpecs()
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .issuerAuth
        )

        // The approved key is the leaf's key, ready to hand to signature verification (C3).
        #expect(publicKey == built.path[0].publicKey)
    }

    // MARK: - AC2: a valid ReaderAuth profile approves the path

    @Test("A fully compliant ReaderAuth path is approved and returns the leaf public key")
    func validReaderAuthApproved() async throws {
        let specs = Factory.readerAuthSpecs()
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .readerAuth
        )

        #expect(publicKey == built.path[0].publicKey)
    }

    @Test("A compliant single-intermediate-free IssuerAuth path (root → leaf) is approved")
    func validIssuerAuthNoIntermediate() async throws {
        let specs = Factory.issuerAuthSpecs()
        let built = try Factory.build(root: specs.root, intermediate: nil, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .issuerAuth
        )
        #expect(publicKey == built.path[0].publicKey)
    }

    // MARK: - AC3: shared profile violations identify the failed rule

    @Test("A non-v3 candidate certificate fails with the Version diagnostic")
    func nonV3Version() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.intermediate.version = .v1
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.version)
    }

    @Test("A candidate certificate without a commonName fails with the Subject diagnostic")
    func missingCommonName() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.commonName = nil
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.subject)
    }

    @Test("A candidate certificate whose countryName is not GB fails with the Subject diagnostic")
    func wrongCountryName() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.intermediate.countryName = "US"
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.subject)
    }

    @Test("An intermediate without critical BasicConstraints fails with the BasicConstraints diagnostic")
    func intermediateBasicConstraintsNotCritical() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.intermediate.basicConstraints = (.isCertificateAuthority(maxPathLength: nil), false)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.basicConstraints)
    }

    @Test("An intermediate with cA=false fails with the BasicConstraints diagnostic")
    func intermediateNotCA() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.intermediate.basicConstraints = (.notCertificateAuthority, true)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.basicConstraints)
    }

    @Test("An end-entity with BasicConstraints cA=true fails with the BasicConstraints diagnostic")
    func endEntityIsCA() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.basicConstraints = (.isCertificateAuthority(maxPathLength: nil), false)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.basicConstraints)
    }

    @Test("An intermediate whose KeyUsage is not exactly keyCertSign+cRLSign fails with the KeyUsage diagnostic")
    func intermediateWrongKeyUsage() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.intermediate.keyUsage = KeyUsage(digitalSignature: true, keyCertSign: true, cRLSign: true)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.keyUsage)
    }

    @Test("An end-entity whose KeyUsage is not exactly digitalSignature fails with the KeyUsage diagnostic")
    func endEntityWrongKeyUsage() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.keyUsage = KeyUsage(digitalSignature: true, keyCertSign: true)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.keyUsage)
    }

    @Test("An end-entity with no KeyUsage extension fails with the KeyUsage diagnostic")
    func endEntityNoKeyUsage() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.keyUsage = nil
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.keyUsage)
    }

    // MARK: - AC4: trust-path-specific violations identify the failed rule

    @Test("An IssuerAuth leaf without the IssuerAuth EKU OID fails with the ExtendedKeyUsage diagnostic")
    func issuerAuthMissingEKU() async throws {
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.extendedKeyUsageOIDs = [[1, 0, 18013, 5, 1, 6]] // ReaderAuth OID, not IssuerAuth
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.extendedKeyUsage)
    }

    @Test("A ReaderAuth leaf without the ReaderAuth EKU OID fails with the ExtendedKeyUsage diagnostic")
    func readerAuthMissingEKU() async throws {
        var specs = Factory.readerAuthSpecs()
        specs.leaf.extendedKeyUsageOIDs = [[1, 0, 18013, 5, 1, 2]] // IssuerAuth OID, not ReaderAuth
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.extendedKeyUsage)
    }

    @Test("An IssuerAuth leaf whose validity exceeds 457 days fails with the ValidityPeriod diagnostic")
    func issuerAuthValidityTooLong() async throws {
        var specs = Factory.issuerAuthSpecs()
        // 500 days, exceeding the 457-day IssuerAuth limit.
        specs.leaf.notValidBefore = Date(timeIntervalSince1970: 1_790_000_000)
        specs.leaf.notValidAfter = specs.leaf.notValidBefore.addingTimeInterval(500 * 24 * 60 * 60)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.validityPeriod)
    }

    @Test("A ReaderAuth leaf whose validity exceeds 1187 days fails with the ValidityPeriod diagnostic")
    func readerAuthValidityTooLong() async throws {
        var specs = Factory.readerAuthSpecs()
        // 1200 days, exceeding the 1187-day ReaderAuth limit.
        specs.leaf.notValidBefore = Date(timeIntervalSince1970: 1_790_000_000)
        specs.leaf.notValidAfter = specs.leaf.notValidBefore.addingTimeInterval(1200 * 24 * 60 * 60)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.validityPeriod)
    }

    @Test("An IssuerAuth leaf with an 800-day validity is approved (within the ReaderAuth-only range)")
    func issuerAuthLimitIsRoleSpecific() async throws {
        // 800 days: over the 457-day IssuerAuth limit but under the 1187-day ReaderAuth limit. It
        // must be rejected for IssuerAuth (proving the limit is role-specific, not shared).
        var specs = Factory.issuerAuthSpecs()
        specs.leaf.notValidBefore = Date(timeIntervalSince1970: 1_790_000_000)
        specs.leaf.notValidAfter = specs.leaf.notValidBefore.addingTimeInterval(800 * 24 * 60 * 60)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .issuerAuth, reason: CertificateProfileReason.validityPeriod)
    }

    @Test("A ReaderAuth path that violates NameConstraints fails with the NameConstraints diagnostic")
    func readerAuthNameConstraintsViolation() async throws {
        // The intermediate permits only subjects under C=GB, O=Permitted. The leaf's subject
        // (C=GB, CN=…) is not under that subtree, so RFC 5280 prefix matching rejects the path.
        var specs = Factory.readerAuthSpecs()
        let permittedSubtree = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Permitted Org")
        }
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permittedSubtree)]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.nameConstraints)
    }

    @Test("A ReaderAuth path whose leaf falls within the permitted NameConstraints subtree is approved")
    func readerAuthNameConstraintsSatisfied() async throws {
        // The intermediate permits subjects under C=GB. The leaf's subject is C=GB, CN=…, which is a
        // superset of (i.e. extends) the permitted prefix, so prefix matching accepts it.
        var specs = Factory.readerAuthSpecs()
        let permittedSubtree = try DistinguishedName {
            CountryName("GB")
        }
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permittedSubtree)]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .readerAuth
        )
        #expect(publicKey == built.path[0].publicKey)
    }

    @Test("IssuerAuth does not enforce NameConstraints (a constraint that would fail ReaderAuth is ignored)")
    func issuerAuthIgnoresNameConstraints() async throws {
        // Same violating constraint as the ReaderAuth failure case, but under IssuerAuth the
        // NameConstraints check is not part of the profile, so the path is approved.
        var specs = Factory.issuerAuthSpecs()
        let permittedSubtree = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Permitted Org")
        }
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permittedSubtree)]),
            false // non-critical so C5-equivalent handling does not reject on the extension itself
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .issuerAuth
        )
        #expect(publicKey == built.path[0].publicKey)
    }

    // MARK: - Non-directoryName constraints are rejected (fail-closed)

    @Test("A ReaderAuth path whose CA carries a dNSName permitted subtree is rejected with NameConstraints")
    func readerAuthDNSNameConstraintRejected() async throws {
        // dNSName constraints are outside the GDS ReaderAuth profile (which uses directoryName
        // subtrees only). An unvalidatable constraint on the critical nameConstraints extension must
        // cause rejection (RFC 5280), so the path fails closed.
        var specs = Factory.readerAuthSpecs()
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.dnsName("example.gov.uk")]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.nameConstraints)
    }

    @Test("A ReaderAuth path whose CA carries an iPAddress permitted subtree is rejected with NameConstraints")
    func readerAuthIPAddressConstraintRejected() async throws {
        // iPAddress constraints were previously dropped silently (fell through to reject). Assert the
        // fail-closed behaviour explicitly: an unvalidatable IP constraint on the critical extension
        // rejects the path.
        var specs = Factory.readerAuthSpecs()
        // 10.0.0.0/8 encoded as the RFC 5280 address+mask octet pair for an IPv4 constraint.
        let ipConstraint: [UInt8] = [10, 0, 0, 0, 255, 0, 0, 0]
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.ipAddress(ASN1OctetString(contentBytes: ipConstraint[...]))]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.nameConstraints)
    }

    @Test("A ReaderAuth path whose CA carries a URI permitted subtree is rejected with NameConstraints")
    func readerAuthURIConstraintRejected() async throws {
        // uniformResourceIdentifier constraints are outside the profile and unvalidatable here, so
        // the path fails closed.
        var specs = Factory.readerAuthSpecs()
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.uniformResourceIdentifier(".gov.uk")]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        await expectProfileViolation(built, role: .readerAuth, reason: CertificateProfileReason.nameConstraints)
    }

    @Test("A ReaderAuth leaf carrying a benign dNSName SAN is approved under a directoryName constraint")
    func readerAuthBenignDNSNameSANUnderDirectoryNameConstraintApproved() async throws {
        // Guards the reduced switch: when the CA constrains via directoryName only and the leaf
        // happens to carry a non-DN SAN entry (a dNSName), that SAN is enumerated as a presented
        // name and paired with the directoryName constraint. It must land in the
        // `case (.directoryName, _)` branch (continue) — NOT the reject-all default — so the path is
        // still approved. `default:` only fires for a non-directoryName *constraint*, never for a
        // benign non-DN presented name.
        var specs = Factory.readerAuthSpecs()
        let permittedSubtree = try DistinguishedName {
            CountryName("GB")
        }
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permittedSubtree)]),
            true
        )
        // Leaf subject is C=GB, CN=… (within the permitted prefix) and additionally carries a dNSName
        // SAN, which is outside the directoryName constraint form.
        specs.leaf.subjectAlternativeNames = ([.dnsName("reader.example.gov.uk")], false)
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        let publicKey = try await CertificateProfileValidator.validate(
            validatedPath: built,
            role: .readerAuth
        )
        #expect(publicKey == built.path[0].publicKey)
    }

    // MARK: - Structural guards

    @Test("An empty path fails with untrustedCertificate")
    func emptyPath() async throws {
        // A structurally valid root is required to construct the ValidatedPath, but the empty path
        // must be rejected before the root is ever used.
        let specs = Factory.issuerAuthSpecs()
        let built = try Factory.build(root: specs.root, intermediate: nil, leaf: specs.leaf)
        let emptyPath = CertificatePathValidator.ValidatedPath(root: built.root, path: [])

        await #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try await CertificateProfileValidator.validate(
                validatedPath: emptyPath,
                role: .issuerAuth
            )
        }
    }

    // MARK: - Helpers

    /// Asserts that validating `built` under `role` throws
    /// ``CoseVerificationFailure/certificateProfileViolation(reason:)`` with `reason`.
    private func expectProfileViolation(
        _ built: CertificatePathValidator.ValidatedPath,
        role: CertificateProfileValidator.Role,
        reason: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        await #expect(sourceLocation: sourceLocation) {
            _ = try await CertificateProfileValidator.validate(
                validatedPath: built,
                role: role
            )
        } throws: { error in
            error as? CoseVerificationFailure == .certificateProfileViolation(reason: reason)
        }
    }
}
