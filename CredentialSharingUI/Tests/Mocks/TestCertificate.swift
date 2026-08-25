import Foundation
import Security

/// Provides a valid self-signed `SecCertificate` for use in unit tests.
/// This is a real X.509 certificate (EC P-256, CN=Test Issuer) that can be
/// parsed by `SecCertificateCreateWithData`. It has no trust chain and should
/// only be used in test contexts.
enum TestCertificate {
    // swiftlint:disable:next line_length
    private static let base64DER = "MIIBgDCCASegAwIBAgIUVOEboNCA04tyVsELHWT+C9XNYpMwCgYIKoZIzj0EAwIwFjEUMBIGA1UEAwwLVGVzdCBJc3N1ZXIwHhcNMjYwODE4MTAxNDIwWhcNMzYwODE1MTAxNDIwWjAWMRQwEgYDVQQDDAtUZXN0IElzc3VlcjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGMSAO8t+HOpxUBMgVKtL8rW2TXLAUwLICd8C1sB1jr1npySabw0Ry1Fhjz4zkQXmXvJMxrhEg5FOeG1DNzI33ajUzBRMB0GA1UdDgQWBBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAfBgNVHSMEGDAWgBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIDgfVsLSvrcafPDOwNpmMAYSdlxbADGcbDrKAiZ0SSeYAiAwai384arQMjr5Ezw0FBguft578i+vWikUoKtvD1Fe7A=="

    /// A valid `SecCertificate` for test use.
    /// Force-unwrapped because the embedded DER data is known-good at compile time.
    static let issuer: SecCertificate = {
        let data = Data(base64Encoded: base64DER)!
        return SecCertificateCreateWithData(nil, data as CFData)!
    }()
}
