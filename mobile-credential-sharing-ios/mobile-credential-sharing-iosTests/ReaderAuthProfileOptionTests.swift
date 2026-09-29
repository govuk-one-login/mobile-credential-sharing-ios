import Foundation
import SharingOrchestration
import Testing

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("ReaderAuthProfileOption Tests")
struct ReaderAuthProfileOptionTests {

    private var testBundle: Bundle { Bundle(for: ReaderAuthProfileBundleToken.self) }

    @Test("Exactly three profiles are available")
    func threeProfilesAvailable() {
        #expect(ReaderAuthProfileOption.allCases.count == 3)
        #expect(ReaderAuthProfileOption.allCases.contains(.valid))
        #expect(ReaderAuthProfileOption.allCases.contains(.missingPrivacyPolicyURL))
        #expect(ReaderAuthProfileOption.allCases.contains(.invalidNameConstraints))
    }

    @Test("Default profile is valid")
    func defaultIsValid() {
        #expect(ReaderAuthProfileOption.default == .valid)
    }

    @Test("Correct display names")
    func displayNames() {
        #expect(ReaderAuthProfileOption.valid.displayName == "Valid")
        #expect(ReaderAuthProfileOption.missingPrivacyPolicyURL.displayName == "Missing privacy policy URL")
        #expect(ReaderAuthProfileOption.invalidNameConstraints.displayName == "Invalid name constraints")
    }

    @Test(
        "Each profile loads leaf + intermediate chain (root excluded) and a leaf key",
        arguments: ReaderAuthProfileOption.allCases
    )
    func profileLoadsMaterial(option: ReaderAuthProfileOption) throws {
        let profile = try option.load(from: testBundle)

        // x5chain contains leaf + intermediate only — root is excluded.
        #expect(profile.certificateChainDER.count == 2)
        #expect(profile.certificateChainDER.first == profile.leafCertificateDER)
        #expect(profile.certificateChainDER.last == profile.intermediateCertificateDER)

        // Leaf certificate and leaf private key are present and non-empty.
        #expect(!profile.leafCertificateDER.isEmpty)
        #expect(!profile.leafPrivateKeyPEM.isEmpty)
        #expect(!profile.intermediateCertificateDER.isEmpty)
    }

    @Test("All profiles share the same intermediate certificate")
    func sharedIntermediate() throws {
        let valid = try ReaderAuthProfileOption.valid.load(from: testBundle)
        let missing = try ReaderAuthProfileOption.missingPrivacyPolicyURL.load(from: testBundle)
        let invalid = try ReaderAuthProfileOption.invalidNameConstraints.load(from: testBundle)

        #expect(valid.intermediateCertificateDER == missing.intermediateCertificateDER)
        #expect(valid.intermediateCertificateDER == invalid.intermediateCertificateDER)
    }

    @Test("Each profile has a distinct leaf certificate and leaf key")
    func distinctLeaves() throws {
        let valid = try ReaderAuthProfileOption.valid.load(from: testBundle)
        let missing = try ReaderAuthProfileOption.missingPrivacyPolicyURL.load(from: testBundle)
        let invalid = try ReaderAuthProfileOption.invalidNameConstraints.load(from: testBundle)

        #expect(valid.leafCertificateDER != missing.leafCertificateDER)
        #expect(valid.leafCertificateDER != invalid.leafCertificateDER)
        #expect(missing.leafCertificateDER != invalid.leafCertificateDER)

        #expect(valid.leafPrivateKeyPEM != missing.leafPrivateKeyPEM)
        #expect(valid.leafPrivateKeyPEM != invalid.leafPrivateKeyPEM)
        #expect(missing.leafPrivateKeyPEM != invalid.leafPrivateKeyPEM)
    }
}

private class ReaderAuthProfileBundleToken {}
