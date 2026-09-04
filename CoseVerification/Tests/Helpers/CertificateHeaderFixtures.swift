@testable import CoseVerification
import CryptoKit
import Foundation
import SwiftCBOR

// MARK: - Real certificate fixtures

/// Real DER-encoded certificates for `x5chain`/`x5t` tests.
///
/// The certificate-header validator treats each `x5chain` entry as opaque DER and hashes the raw
/// bytes for `x5t`; it never parses them (that is path validation's concern). Using genuine
/// EC P-256 certificates means the thumbprint behaviour runs against real encoded bytes, per the
/// ticket's Definition of Done.
enum CertificateFixtures {
    // swiftlint:disable:next line_length
    private static let leafBase64 = "MIIBgDCCASegAwIBAgIUVOEboNCA04tyVsELHWT+C9XNYpMwCgYIKoZIzj0EAwIwFjEUMBIGA1UEAwwLVGVzdCBJc3N1ZXIwHhcNMjYwODE4MTAxNDIwWhcNMzYwODE1MTAxNDIwWjAWMRQwEgYDVQQDDAtUZXN0IElzc3VlcjBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABGMSAO8t+HOpxUBMgVKtL8rW2TXLAUwLICd8C1sB1jr1npySabw0Ry1Fhjz4zkQXmXvJMxrhEg5FOeG1DNzI33ajUzBRMB0GA1UdDgQWBBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAfBgNVHSMEGDAWgBT9hEJvGkhJQJD1hcKYnFwQvNsJaTAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0cAMEQCIDgfVsLSvrcafPDOwNpmMAYSdlxbADGcbDrKAiZ0SSeYAiAwai384arQMjr5Ezw0FBguft578i+vWikUoKtvD1Fe7A=="

    /// The candidate leaf certificate's DER bytes (a real self-signed EC P-256 test certificate).
    static let leafDER = Data(base64Encoded: leafBase64)!

    /// The correct `x5t` `hashValue`: the SHA-256 digest of `leafDER`.
    static let leafSHA256 = Data(SHA256.hash(data: leafDER))

    /// A distinct DER blob standing in for an intermediate, to exercise order preservation.
    static let intermediateDER = Data([0x30, 0x82, 0x01, 0x00] + [UInt8](repeating: 0xB1, count: 60))
}

// MARK: - COSE header CBOR builders

/// The COSE header label for `x5bag` (32).
func x5bagLabel() -> CBOR { .unsignedInt(32) }
/// The COSE header label for `x5chain` (33).
func x5chainLabel() -> CBOR { .unsignedInt(33) }
/// The COSE header label for `x5t` (34).
func x5tLabel() -> CBOR { .unsignedInt(34) }
/// The COSE algorithm identifier for SHA-256 (-16), encoded as `.negativeInt(15)` (= -1 - 15).
func sha256AlgorithmCBOR() -> CBOR { .negativeInt(15) }

/// Encodes an `x5chain` value as a single certificate byte string.
func x5chainSingle(_ der: Data) -> CBOR {
    .byteString([UInt8](der))
}

/// Encodes an `x5chain` value as an array of certificate byte strings, in the supplied order.
func x5chainArray(_ ders: [Data]) -> CBOR {
    .array(ders.map { .byteString([UInt8]($0)) })
}

/// Encodes an `x5t` thumbprint value as `[hashAlgorithm, hashValue]`.
/// Defaults to SHA-256 (-16) with the given hash bytes.
func x5tValue(algorithm: CBOR? = nil, hash: Data) -> CBOR {
    .array([algorithm ?? sha256AlgorithmCBOR(), .byteString([UInt8](hash))])
}

/// Builds a decoded `CoseSign1` directly from protected and unprotected header maps.
///
/// Drives ``CertificateHeaderValidator`` with precise header shapes without hand-assembling full
/// COSE_Sign1 byte streams. The protected header always includes `alg = -7` (ES256); the payload
/// and signature are placeholders because only the headers are inspected.
func makeCoseSign1(
    protected: [(CBOR, CBOR)] = [],
    unprotected: [(CBOR, CBOR)] = []
) -> CoseSign1 {
    // Placeholders that are never inspected.
    let placeholderPayload: CBOR = .byteString([0x01, 0x02, 0x03])
    let placeholderSignature: CBOR = .byteString([UInt8](repeating: 0xAA, count: 64))

    let es256Alg: (CBOR, CBOR) = (.unsignedInt(1), .negativeInt(6)) // alg: ES256 (-7)
    let protectedBytes = Data(CBOR.map(cborMap([es256Alg] + protected)).encode())

    let fullCose = CBOR.array([
        .byteString([UInt8](protectedBytes)),
        .map(cborMap(unprotected)),
        placeholderPayload,
        placeholderSignature
    ])

    // Round-trip through the real decoder so tests operate on genuinely decoded headers.
    // swiftlint:disable:next force_try
    return try! CoseSign1Decoder.decode(Data(fullCose.encode()))
}

/// Builds a CBOR map dictionary from label/value pairs. Order is irrelevant to the decoder, which
/// detects duplicate labels by pair count rather than position.
private func cborMap(_ pairs: [(CBOR, CBOR)]) -> [CBOR: CBOR] {
    Dictionary(pairs, uniquingKeysWith: { first, _ in first })
}
