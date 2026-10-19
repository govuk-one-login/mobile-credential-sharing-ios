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
    private static let base64DER = "MIICTDCCAdKgAwIBAgIQfeCkdRR7TjhHlBtDU/aMRTAKBggqhkjOPQQDAzBnMQswCQYDVQQGEwJHQjEjMCEGA1UECgwaR292ZXJubWVudCBEaWdpdGFsIFNlcnZpY2UxMzAxBgNVBAMMKkdPVlVLIE1vYmlsZSBXYWxsZXQgVmVyaWZpZXIgUm9vdCBDQSBbSU5UXTAeFw0yNjEwMDUxMDUzNDJaFw0zNjEwMDUxMTUzNDJaMGcxCzAJBgNVBAYTAkdCMSMwIQYDVQQKDBpHb3Zlcm5tZW50IERpZ2l0YWwgU2VydmljZTEzMDEGA1UEAwwqR09WVUsgTW9iaWxlIFdhbGxldCBWZXJpZmllciBSb290IENBIFtJTlRdMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAEl2JHxdb5g6QRYcEv/NT3YyUPrpvnA4kg7nXOLh0nMoUzQFgncoEURTikORnuTyYlDlEUjQH6BvcF6OOjjxZoRP9Ntfn61B6RcRNoESGJEAVkGjNmbbLYzyg/DRAmi8IBo0MwQTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBT+/o2tagVLgYMHTCoFMPXiei8sKjAPBgNVHQ8BAf8EBQMDBwYAMAoGCCqGSM49BAMDA2gAMGUCMG2Mimqr3vwRlsARBIrX8uM0802Hp5XY24uPsaOY4aSzfFkZdkl3TjVojPO266eL5gIxAJjjeeOheSupr/3vDeQcKi9HxQ0RWJMq8lPfsGu3/xQyEj0SbsljPXgGSEsIQrc+3A=="

    static var root: Certificate {
        get throws {
            let der = Data(base64Encoded: base64DER)!
            return try Certificate(derEncoded: Array(der))
        }
    }
}
