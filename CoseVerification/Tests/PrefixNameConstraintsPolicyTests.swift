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
