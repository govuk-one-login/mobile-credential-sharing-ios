import Foundation
import Testing

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("ReaderAuthCertificateValidator Tests")
struct ReaderAuthCertificateValidatorTests {

    private var testBundle: Bundle { Bundle(for: ReaderAuthCertificateValidatorBundleToken.self) }

    /// 2027-01-01T00:00:00Z — comfortably inside the valid leaf's window
    /// (notBefore 2026-09-25, notAfter 2027-09-25) so the "valid" assertion is deterministic.
    private var validationTime: Date {
        var components = DateComponents()
        components.year = 2027
        components.month = 1
        components.day = 1
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test("A real in-date leaf certificate is valid")
    func realLeafIsValid() {
        let validator = ReaderAuthCertificateValidator(validationTime: validationTime, bundle: testBundle)
        #expect(validator.validate(.valid) == .valid)
    }

    @Test("Unprovisioned DVS options are placeholders")
    func dvsOptionsArePlaceholders() {
        let validator = ReaderAuthCertificateValidator(validationTime: validationTime, bundle: testBundle)
        #expect(validator.validate(.dvsLowerEnv) == .placeholder)
        #expect(validator.validate(.dvsIntegration) == .placeholder)
    }

    @Test("The placeholder sentinel classifies as placeholder")
    func sentinelIsPlaceholder() {
        let validator = ReaderAuthCertificateValidator(validationTime: validationTime, bundle: testBundle)
        let sentinel = Data("""
        -----BEGIN CERTIFICATE-----
        DVS_PLACEHOLDER_CERTIFICATE_REPLACE_IN_CI
        -----END CERTIFICATE-----
        """.utf8)
        #expect(validator.classify(sentinel) == .placeholder)
    }

    @Test("Non-certificate bytes are treated as placeholder")
    func garbageIsPlaceholder() {
        let validator = ReaderAuthCertificateValidator(validationTime: validationTime, bundle: testBundle)
        #expect(validator.classify(Data("this is not a certificate".utf8)) == .placeholder)
    }

    @Test("A real certificate outside its validity window is a placeholder")
    func expiredLeafIsPlaceholder() {
        // Validate the real valid leaf at an instant long after its notAfter (2027-09-25).
        var components = DateComponents()
        components.year = 2099
        components.timeZone = TimeZone(identifier: "UTC")
        let future = Calendar(identifier: .gregorian).date(from: components)!

        let validator = ReaderAuthCertificateValidator(validationTime: future, bundle: testBundle)
        #expect(validator.validate(.valid) == .placeholder)
    }
}

private class ReaderAuthCertificateValidatorBundleToken {}
