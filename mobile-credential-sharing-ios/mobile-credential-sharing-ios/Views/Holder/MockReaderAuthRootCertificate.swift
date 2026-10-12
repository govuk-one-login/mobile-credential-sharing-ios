import Foundation
import SwiftASN1
import X509

/// Test app's mock ReaderAuth root, supplied to `CredentialPresenter` for Holder journeys.
/// The SDK never hardcodes a root; the host supplies it. Replace with a real root CA in production.
enum MockReaderAuthRootCertificate {
    // Self-signed EC P-256 reader-auth root (CN=mDoc Test Issuer, O=DVLA Dev Tool) for test/demo
    // use. This is the root that signed the demo Verifier's reader chain
    // (reader_intermediate_x509_certificate / reader_valid_x509_leaf_certificate), SKI
    // 71:F7:D9:BD:92:22:0A:C9:82:4C:BC:AA:03:F0:1F:42:48:C3:11:42. Validity: 2026-09-25 → 2027-09-25.
    // swiftlint:disable:next line_length
    private static let base64DER = "MIICWTCCAgCgAwIBAgIUQRJ4BD5wIrgxkb+mfW7Trs02TGEwCgYIKoZIzj0EAwIwUTELMAkGA1UEBhMCR0IxDzANBgNVBAgMBkxvbmRvbjEZMBcGA1UEAwwQbURvYyBUZXN0IElzc3VlcjEWMBQGA1UECgwNRFZMQSBEZXYgVG9vbDAeFw0yNjA5MjUxMjA3MDRaFw0yNzA5MjUxMjA3MDRaMFExCzAJBgNVBAYTAkdCMQ8wDQYDVQQIDAZMb25kb24xGTAXBgNVBAMMEG1Eb2MgVGVzdCBJc3N1ZXIxFjAUBgNVBAoMDURWTEEgRGV2IFRvb2wwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATop3muD5jRcBOEQSVLLgBVcWz7w6UMHqSFvqRBW5BW9sfXUgO0VoLQasQoA/EKeiVJQg6V6r1lyd1D06x3TZjko4G1MIGyMB0GA1UdDgQWBBRx99m9kiIKyYJMvKoD8B9CSMMRQjAfBgNVHSMEGDAWgBRx99m9kiIKyYJMvKoD8B9CSMMRQjAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBhjAeBgNVHSUBAf8EFDASBgcogYxdBQEGBgcogbU0BAEGMC8GCCsGAQUFBwEBBCMwITAfBggrBgEFBQcwAYYTaHR0cHM6Ly93d3cuZ292LnVrLzAKBggqhkjOPQQDAgNHADBEAiAYPrZC9CQa76GuJQF8RVSkVzk5XjPUksnmuzFnzw5LkQIgXubad/v0Gjzs+C40WbZ0VL9eqOpf5r0v3soQlwQ6H80="

    static var root: Certificate {
        get throws {
            let der = Data(base64Encoded: base64DER)!
            return try Certificate(derEncoded: Array(der))
        }
    }
}
