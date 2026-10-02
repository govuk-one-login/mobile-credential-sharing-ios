import Foundation
@testable import ReaderAuthentication
import Testing

/// Tests for R5 privacy-policy extraction and validation.
///
/// `PrivacyPolicyValidator` runs entirely offline: it parses the SIA extension
/// on a verified Reader leaf, validates the privacy-policy URL against the
/// ISO rules, and extracts the subject `organizationName` without validation.
/// There is no injectable network layer — the implementation only uses
/// `URLComponents`/`URL` — so the "no network activity" ACs are satisfied
/// structurally rather than via a network spy.
@Suite("PrivacyPolicyValidator Tests")
struct PrivacyPolicyValidatorTests {

    // MARK: - AC1: Valid privacy metadata authenticates the same candidate

    @Test("valid metadata returns the same docRequest, parsed URL, and org name")
    func validMetadataAuthenticatesCandidate() throws {
        let docRequest = try ReaderAuthFixtures.requestedDocument()
        let leaf = try ReaderAuthFixtures.leafCertificate(
            organizationName: "Government Digital Service",
            siaEntries: [.privacyPolicy(uri: "https://example.gov.uk/privacy")]
        )

        let result = try PrivacyPolicyValidator.validate(
            docRequest: docRequest,
            verifiedReaderLeaf: leaf
        )

        #expect(result.docRequest == docRequest)
        #expect(result.privacyPolicyURL == URL(string: "https://example.gov.uk/privacy"))
        #expect(result.organizationName == "Government Digital Service")
    }

    @Test("returned URL preserves the exact validated absolute ASCII string")
    func urlStringIsPreservedVerbatim() throws {
        let raw = "https://example.gov.uk/privacy?lang=en-GB&v=2"
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: raw)])

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.privacyPolicyURL.absoluteString == raw)
    }

    @Test("an internationalised host in ASCII punycode is accepted")
    func punycodeHostIsAccepted() throws {
        // "exämple.gov.uk" expressed as punycode — pure ASCII, so it survives
        // IA5String decoding and must satisfy the host rule (not over-rejected).
        let raw = "https://xn--exmple-cua.gov.uk/privacy"
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: raw)])

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.privacyPolicyURL.absoluteString == raw)
    }

    // MARK: - AC2: A missing privacy-policy SIA entry throws the privacy failure

    @Test("missing SIA extension throws privacyPolicyURLInvalid")
    func missingSIAExtensionThrows() throws {
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: nil)

        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }

    @Test("SIA extension without the privacy-policy OID throws privacyPolicyURLInvalid")
    func siaWithoutPrivacyPolicyOIDThrows() throws {
        // A present SIA entry, but for a different (CA-issuers) access method.
        let otherEntry = ReaderAuthFixtures.AccessEntry(
            accessMethod: [1, 3, 6, 1, 5, 5, 7, 48, 5], // id-ad-caRepository
            accessLocation: .uri("https://example.gov.uk/ca")
        )
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [otherEntry])

        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }

    @Test("matching OID with a non-URI access location throws privacyPolicyURLInvalid")
    func privacyPolicyEntryWithNonURILocationThrows() throws {
        let leaf = try ReaderAuthFixtures.leafCertificate(
            siaEntries: [.privacyPolicy(dnsName: "example.gov.uk")]
        )

        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }

    // MARK: - AC3: A URI that violates a required condition throws the privacy failure

    // Each case is ASCII-encodable (so it survives IA5String decoding and reaches
    // the validator) and breaks exactly one URL rule while satisfying the rest.
    //
    // The validator's non-ASCII guards (Unicode host label, non-ASCII path char)
    // are deliberately NOT exercised here: a `uniformResourceIdentifier` is an
    // IA5String, and swift-asn1 rejects bytes >= 128 on *decode*
    // (`ASN1IA5String.init(derEncoded:)`), so a non-ASCII URI fails while the
    // certificate's SIA extension is parsed — before `PrivacyPolicyValidator` runs.
    // `nonASCIIURIFailsCertificateDecoding` covers that upstream enforcement.
    @Test("each single URL-rule violation throws privacyPolicyURLInvalid", arguments: [
        "not a url",                                    // not parseable / contains spaces
        "http://example.gov.uk/privacy",                // scheme not HTTPS
        "ftp://example.gov.uk/privacy",                 // non-HTTPS scheme, parseable
        "https:///privacy",                             // empty host
        "https://user:pass@example.gov.uk/privacy",     // user info with password
        "https://user@example.gov.uk/privacy",          // user info without password
        "https://example.gov.uk/pri vacy"               // space in the value
    ])
    func singleRuleViolationThrows(rawURL: String) throws {
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: rawURL)])

        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }

    @Test("uppercase HTTPS scheme is accepted (case-insensitive)")
    func uppercaseSchemeIsAccepted() throws {
        let raw = "HTTPS://example.gov.uk/privacy"
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: raw)])

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.privacyPolicyURL.absoluteString == raw)
    }

    @Test("a 2048-character URL is accepted at the boundary")
    func maxLengthURLIsAccepted() throws {
        let prefix = "https://example.gov.uk/"
        let raw = prefix + String(repeating: "a", count: 2048 - prefix.count)
        #expect(raw.count == 2048)
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: raw)])

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.privacyPolicyURL.absoluteString == raw)
    }

    @Test("a 2049-character URL is rejected just over the boundary")
    func overMaxLengthURLIsRejected() throws {
        let prefix = "https://example.gov.uk/"
        let raw = prefix + String(repeating: "a", count: 2049 - prefix.count)
        #expect(raw.count == 2049)
        let leaf = try ReaderAuthFixtures.leafCertificate(siaEntries: [.privacyPolicy(uri: raw)])

        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }

    // MARK: - AC4: Organization name is extracted and returned without validation

    @Test("organizationName is extracted verbatim")
    func organizationNameExtractedVerbatim() throws {
        let leaf = try ReaderAuthFixtures.leafCertificate(
            organizationName: "Cabinet Office",
            siaEntries: [.privacyPolicy(uri: "https://example.gov.uk/privacy")]
        )

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.organizationName == "Cabinet Office")
    }

    @Test("an unusual organizationName is returned without rejection")
    func unusualOrganizationNameIsNotValidated() throws {
        let unusual = "  🏛️  Gov  "
        let leaf = try ReaderAuthFixtures.leafCertificate(
            organizationName: unusual,
            siaEntries: [.privacyPolicy(uri: "https://example.gov.uk/privacy")]
        )

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.organizationName == unusual)
    }

    @Test("a missing organizationName yields nil and still succeeds")
    func missingOrganizationNameYieldsNil() throws {
        let leaf = try ReaderAuthFixtures.leafCertificate(
            organizationName: nil,
            siaEntries: [.privacyPolicy(uri: "https://example.gov.uk/privacy")]
        )

        let result = try PrivacyPolicyValidator.validate(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            verifiedReaderLeaf: leaf
        )

        #expect(result.organizationName == nil)
        #expect(result.privacyPolicyURL == URL(string: "https://example.gov.uk/privacy"))
    }

    // MARK: - Non-ASCII enforcement happens upstream (at certificate decode)

    @Test("a non-ASCII URI is rejected while parsing the certificate SIA, before validation")
    func nonASCIIURIFailsCertificateDecoding() throws {
        // "https://exämple.gov.uk" with the 'ä' as raw UTF-8 bytes (0xC3 0xA4):
        // valid UTF-8 but NOT valid IA5String, so decoding the GeneralName throws.
        let prefix = Array("https://ex".utf8)
        let suffix = Array("mple.gov.uk/privacy".utf8)
        let rawBytes = prefix + [0xC3, 0xA4] + suffix

        let leaf = try ReaderAuthFixtures.leafCertificate(
            siaEntries: [ReaderAuthFixtures.AccessEntry(
                accessMethod: ReaderAuthFixtures.privacyPolicyAccessMethodOID,
                accessLocation: .rawURIBytes(rawBytes)
            )]
        )

        // The SIA decode (inside the validator's SubjectInformationAccess init)
        // rejects the non-ASCII IA5String, surfacing as privacyPolicyURLInvalid.
        // The URL rule checks are never reached — enforcement is upstream.
        #expect(throws: ReaderAuthenticationFailure.privacyPolicyURLInvalid) {
            try PrivacyPolicyValidator.validate(
                docRequest: try ReaderAuthFixtures.requestedDocument(),
                verifiedReaderLeaf: leaf
            )
        }
    }
}
