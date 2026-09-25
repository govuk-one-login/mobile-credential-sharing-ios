@testable import CoseVerification
import Foundation
import SwiftASN1
import Testing
import X509

/// Unit tests for ``PrefixNameConstraintsPolicy``'s directoryName prefix-matching primitive.
///
/// These exercise the matching rule directly (independent of a full chain), pinning the parity
/// semantics we previously relied on from the forked `RFC5280Policy`: RFC 5280 prefix matching with
/// case-insensitive, encoding-tolerant attribute-value comparison.
@Suite("Prefix NameConstraints directoryName matching")
struct PrefixNameConstraintsPolicyTests {

    // MARK: - Helpers

    private func dn(_ build: () throws -> DistinguishedName) rethrows -> DistinguishedName {
        try build()
    }

    private func matches(name: DistinguishedName, constraint: DistinguishedName) -> Bool {
        PrefixNameConstraintsPolicy.directoryNameMatchesConstraint(
            directoryName: name,
            constraint: constraint
        )
    }

    // MARK: - Prefix semantics

    @Test("An exact DN match is accepted")
    func exactMatch() throws {
        let name = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Cabinet Office")
        }
        let constraint = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Cabinet Office")
        }
        #expect(matches(name: name, constraint: constraint))
    }

    @Test("A constraint that is a proper prefix of the presented DN is accepted")
    func properPrefixAccepted() throws {
        // Constraint C=GB is a prefix of C=GB, O=…, CN=…
        let name = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Cabinet Office")
            CommonName("Reader 1")
        }
        let constraint = try DistinguishedName {
            CountryName("GB")
        }
        #expect(matches(name: name, constraint: constraint))
    }

    @Test("A constraint longer than the presented DN is rejected")
    func longerConstraintRejected() throws {
        let name = try DistinguishedName {
            CountryName("GB")
        }
        let constraint = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Cabinet Office")
        }
        #expect(!matches(name: name, constraint: constraint))
    }

    @Test("A divergent RDN within the prefix is rejected")
    func divergentPrefixRejected() throws {
        let name = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Some Other Org")
        }
        let constraint = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Cabinet Office")
        }
        #expect(!matches(name: name, constraint: constraint))
    }

    @Test("A different value in the leading RDN is rejected")
    func differentLeadingValueRejected() throws {
        let name = try DistinguishedName {
            CountryName("US")
            OrganizationName("Cabinet Office")
        }
        let constraint = try DistinguishedName {
            CountryName("GB")
        }
        #expect(!matches(name: name, constraint: constraint))
    }

    // MARK: - Case-insensitivity & encoding tolerance

    @Test("Attribute values match case-insensitively")
    func caseInsensitiveValues() throws {
        let name = try DistinguishedName {
            CountryName("GB")
            OrganizationName("cabinet office")
        }
        let constraint = try DistinguishedName {
            CountryName("gb")
            OrganizationName("CABINET OFFICE")
        }
        #expect(matches(name: name, constraint: constraint))
    }

    @Test("PrintableString and UTF8String encodings of the same text compare equal")
    func encodingToleranceValues() throws {
        // Build the same logical DN but force different string encodings for the O attribute.
        let name = try DistinguishedName([
            RelativeDistinguishedName.Attribute(type: .RDNAttributeType.countryName, printableString: "GB"),
            RelativeDistinguishedName.Attribute(type: .RDNAttributeType.organizationName, utf8String: "Cabinet Office")
        ])
        let constraint = try DistinguishedName([
            RelativeDistinguishedName.Attribute(type: .RDNAttributeType.countryName, printableString: "GB"),
            RelativeDistinguishedName.Attribute(type: .RDNAttributeType.organizationName, printableString: "Cabinet Office")
        ])
        #expect(matches(name: name, constraint: constraint))
    }

    // MARK: - Empty constraint

    @Test("An empty constraint matches any DN (zero-length prefix)")
    func emptyConstraintMatchesAnything() throws {
        let name = try DistinguishedName {
            CountryName("GB")
            CommonName("Anything")
        }
        let constraint = try DistinguishedName {}
        #expect(matches(name: name, constraint: constraint))
    }
}

/// Direct tests of ``PrefixNameConstraintsPolicy``'s chain-walk (`evaluate(chain:)`), which applies
/// each issuer's name constraints to every certificate below it in a leaf-first path.
///
/// These drive the walk directly on `[Certificate]` arrays (index 0 = leaf, last = root/anchor),
/// since `UnverifiedCertificateChain` cannot be constructed outside the X509 module. They cover the
/// single-certificate self-issued branch, the no-constraints fast path, and — critically — that a
/// constraint on a higher CA is transitively applied to certificates further down the path, not just
/// to its immediate child.
@Suite("Prefix NameConstraints chain walk")
struct PrefixNameConstraintsPolicyChainWalkTests {
    private typealias Factory = ProfileCertificateFactory

    /// Assembles the leaf-first-including-root array the verifier hands to the policy.
    private func chain(_ built: CertificatePathValidator.ValidatedPath) -> [Certificate] {
        built.path + [built.root]
    }

    private func isMeetsPolicy(_ result: PolicyEvaluationResult) -> Bool {
        if case .meetsPolicy = result { return true }
        return false
    }

    // MARK: - Single certificate (self-issued)

    @Test("A single self-signed cert whose own constraints permit its own subject meets policy")
    func singleSelfIssuedSatisfied() throws {
        var spec = Factory.caSpec(commonName: "Self")
        // Permit C=GB; the cert's own subject is C=GB, CN=Self, which extends that prefix.
        let permitted = try DistinguishedName { CountryName("GB") }
        spec.nameConstraints = (NameConstraints(permittedSubtrees: [.directoryName(permitted)]), true)
        let cert = try Factory.selfSigned(spec)

        #expect(isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: [cert])))
    }

    @Test("A single self-signed cert whose own constraints exclude its own subject fails")
    func singleSelfIssuedExcluded() throws {
        var spec = Factory.caSpec(commonName: "Self")
        // Exclude C=GB; the cert's own subject is under C=GB, so it is forbidden.
        let excluded = try DistinguishedName { CountryName("GB") }
        spec.nameConstraints = (NameConstraints(excludedSubtrees: [.directoryName(excluded)]), true)
        let cert = try Factory.selfSigned(spec)

        #expect(!isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: [cert])))
    }

    // MARK: - No constraints

    @Test("A multi-cert path with no name constraints anywhere meets policy")
    func multiCertNoConstraints() throws {
        let specs = Factory.readerAuthSpecs()
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        #expect(isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: chain(built))))
    }

    // MARK: - Constraint applied to the immediate child

    @Test("An intermediate's constraint that its leaf violates fails")
    func intermediateConstraintRejectsLeaf() throws {
        var specs = Factory.readerAuthSpecs()
        let permitted = try DistinguishedName {
            CountryName("GB")
            OrganizationName("Permitted Org")
        }
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permitted)]),
            true
        )
        // Leaf subject is C=GB, CN=… — not under C=GB, O=Permitted Org.
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        #expect(!isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: chain(built))))
    }

    // MARK: - Transitivity: a higher CA's constraint reaches the leaf

    @Test("A root constraint the intermediate satisfies but the leaf violates rejects the path")
    func rootConstraintReachesLeaf() throws {
        var specs = Factory.readerAuthSpecs()
        // Root permits exactly C=GB, CN=Test Intermediate. The intermediate's own subject matches it
        // exactly, so the intermediate passes; the leaf's subject is C=GB, CN=Test ReaderAuth Leaf,
        // whose second RDN diverges, so the leaf must be rejected — proving the ROOT's constraint is
        // applied transitively to the leaf, not just to its immediate child (the intermediate).
        let permitted = try DistinguishedName {
            CountryName("GB")
            CommonName("Test Intermediate")
        }
        specs.root.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permitted)]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        #expect(!isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: chain(built))))
    }

    @Test("A root constraint that both the intermediate and leaf satisfy meets policy")
    func rootConstraintSatisfiedByWholeSubtree() throws {
        var specs = Factory.readerAuthSpecs()
        // Root permits C=GB, satisfied by both the intermediate (C=GB, CN=…) and the leaf (C=GB, CN=…).
        let permitted = try DistinguishedName { CountryName("GB") }
        specs.root.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(permitted)]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        #expect(isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: chain(built))))
    }

    @Test("Both a root and an intermediate constraint are enforced together")
    func rootAndIntermediateConstraintsBothEnforced() throws {
        var specs = Factory.readerAuthSpecs()
        // Root permits C=GB (satisfied by all). Intermediate permits C=GB, CN=Nonexistent — which the
        // leaf does not satisfy — so the path must be rejected by the intermediate's constraint even
        // though the root's is satisfied.
        specs.root.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(try DistinguishedName { CountryName("GB") })]),
            true
        )
        specs.intermediate.nameConstraints = (
            NameConstraints(permittedSubtrees: [.directoryName(try DistinguishedName {
                CountryName("GB")
                CommonName("Nonexistent")
            })]),
            true
        )
        let built = try Factory.build(root: specs.root, intermediate: specs.intermediate, leaf: specs.leaf)

        #expect(!isMeetsPolicy(PrefixNameConstraintsPolicy.evaluate(chain: chain(built))))
    }
}
