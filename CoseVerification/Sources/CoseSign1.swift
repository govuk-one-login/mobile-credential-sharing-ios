import Foundation

/// Internal representation of a decoded COSE_Sign1 structure (RFC 9052 §4.2).
///
/// Preserves the original serialised bytes for the protected header and any attached payload,
/// because the signature authenticates their exact encoding — not a decoded and re-encoded
/// equivalent.
///
/// This type is internal to the `CoseVerification` module. It is never exposed publicly.
struct CoseSign1: Sendable {
    /// The original serialised protected-header bytes (element 0 of the COSE_Sign1 array).
    /// Used verbatim in `Sig_structure` construction.
    let protectedHeaderBytes: Data

    /// Decoded key-value pairs from the protected header map.
    let protectedHeader: CoseHeaderMap

    /// Decoded key-value pairs from the unprotected header map (element 1).
    let unprotectedHeader: CoseHeaderMap

    /// The attached payload bytes, or `nil` if the payload field was CBOR null (detached mode).
    let payload: Data?

    /// The signature bytes (element 3 of the COSE_Sign1 array).
    let signature: Data
}
