import Foundation
import SharingOrchestration
import Testing

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("ReaderAuthProfileOption Tests")
struct ReaderAuthProfileOptionTests {

    private var testBundle: Bundle { Bundle(for: ReaderAuthProfileBundleToken.self) }

    /// The mock profiles backed by separate leaf + shared-intermediate resources.
    private static let mockProfiles: [ReaderAuthProfileOption] = [
        .valid, .missingPrivacyPolicyURL, .invalidNameConstraints
    ]

    @Test("Exactly five profiles are available")
    func fiveProfilesAvailable() {
        #expect(ReaderAuthProfileOption.allCases.count == 5)
        #expect(ReaderAuthProfileOption.allCases.contains(.valid))
        #expect(ReaderAuthProfileOption.allCases.contains(.missingPrivacyPolicyURL))
        #expect(ReaderAuthProfileOption.allCases.contains(.invalidNameConstraints))
        #expect(ReaderAuthProfileOption.allCases.contains(.dvsLowerEnv))
        #expect(ReaderAuthProfileOption.allCases.contains(.dvsIntegration))
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
        #expect(ReaderAuthProfileOption.dvsLowerEnv.displayName == "Wallet Test App (Lower Env)")
        #expect(ReaderAuthProfileOption.dvsIntegration.displayName == "Wallet Test App (Integration)")
    }

    @Test("Only DVS profiles are pipeline-provisioned")
    func pipelineProvisionedFlag() {
        #expect(ReaderAuthProfileOption.valid.isPipelineProvisioned == false)
        #expect(ReaderAuthProfileOption.missingPrivacyPolicyURL.isPipelineProvisioned == false)
        #expect(ReaderAuthProfileOption.invalidNameConstraints.isPipelineProvisioned == false)
        #expect(ReaderAuthProfileOption.dvsLowerEnv.isPipelineProvisioned == true)
        #expect(ReaderAuthProfileOption.dvsIntegration.isPipelineProvisioned == true)
    }

    @Test("DVS profiles resolve to their single chain and leaf-key resources")
    func dvsResourceNames() {
        #expect(ReaderAuthProfileOption.dvsLowerEnv.leafCertificateResource == "reader_dvs_dev_chain")
        #expect(ReaderAuthProfileOption.dvsIntegration.leafCertificateResource == "reader_dvs_integration_chain")
    }

    @Test(
        "Each mock profile loads a leaf + intermediate chain (root excluded) and a leaf key",
        arguments: mockProfiles
    )
    func mockProfileLoadsMaterial(option: ReaderAuthProfileOption) throws {
        let profile = try option.load(from: testBundle)

        // x5chain contains leaf + intermediate only — root is excluded.
        #expect(profile.certificateChainDER.count == 2)
        #expect(profile.certificateChainDER.first == profile.leafCertificateDER)
        #expect(profile.certificateChainDER.last == profile.intermediateCertificateDER)

        // Leaf certificate and leaf private key are present and non-empty.
        #expect(!profile.leafCertificateDER.isEmpty)
        #expect(!profile.leafPrivateKeyPEM.isEmpty)
        #expect(profile.intermediateCertificateDER?.isEmpty == false)
    }

    @Test("An unprovisioned DVS placeholder chain fails to load (fails closed)")
    func dvsPlaceholderFailsToLoad() {
        // The committed placeholder .der is PEM-wrapped sentinel text, not a DER certificate,
        // so splitting produces zero certificates and load() throws emptyCertificateChain.
        #expect(throws: ReaderAuthProfileError.self) {
            _ = try ReaderAuthProfileOption.dvsLowerEnv.load(from: testBundle)
        }
        #expect(throws: ReaderAuthProfileError.self) {
            _ = try ReaderAuthProfileOption.dvsIntegration.load(from: testBundle)
        }
    }

    @Test("All mock profiles share the same intermediate certificate")
    func sharedIntermediate() throws {
        let valid = try ReaderAuthProfileOption.valid.load(from: testBundle)
        let missing = try ReaderAuthProfileOption.missingPrivacyPolicyURL.load(from: testBundle)
        let invalid = try ReaderAuthProfileOption.invalidNameConstraints.load(from: testBundle)

        #expect(valid.intermediateCertificateDER == missing.intermediateCertificateDER)
        #expect(valid.intermediateCertificateDER == invalid.intermediateCertificateDER)
    }

    @Test("Each mock profile has a distinct leaf certificate and leaf key")
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

    // MARK: - DER chain splitting

    @Test("Splitting a two-certificate DER buffer preserves order, leaf first")
    func splitTwoCertificates() {
        // Two minimal DER SEQUENCEs (tag 0x30) with short-form lengths.
        let leaf = Data([0x30, 0x03, 0x0A, 0x0B, 0x0C])          // SEQUENCE, len 3
        let intermediate = Data([0x30, 0x02, 0x01, 0x02])        // SEQUENCE, len 2
        let chain = leaf + intermediate

        let certificates = ReaderAuthProfileOption.splitDERCertificates(chain)

        #expect(certificates.count == 2)
        #expect(certificates.first == leaf)
        #expect(certificates.last == intermediate)
    }

    @Test("Splitting handles long-form length encoding")
    func splitLongFormLength() {
        // SEQUENCE with long-form length: 0x81 means 1 length byte follows (value 0x80 = 128).
        let body = Data(repeating: 0xAB, count: 128)
        let cert = Data([0x30, 0x81, 0x80]) + body

        let certificates = ReaderAuthProfileOption.splitDERCertificates(cert)

        #expect(certificates.count == 1)
        #expect(certificates.first == cert)
    }

    @Test("Splitting non-certificate bytes yields an empty array")
    func splitNonCertificate() {
        let garbage = Data("DVS_PLACEHOLDER_CERTIFICATE_REPLACE_IN_CI".utf8)
        #expect(ReaderAuthProfileOption.splitDERCertificates(garbage).isEmpty)
    }
}

private class ReaderAuthProfileBundleToken {}
