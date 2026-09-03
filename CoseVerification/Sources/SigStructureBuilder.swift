import Foundation
import SwiftCBOR

/// Builds the COSE `Sig_structure` that ES256 signatures are computed over (RFC 9052 §4.4):
/// `["Signature1", protected_header_bstr, external_aad, payload_bstr]`.
/// The protected-header bytes are passed through unchanged, since the signature covers
/// their exact encoding.
enum SigStructureBuilder {

    private static let signature1 = "Signature1"

    /// Builds the CBOR-encoded `Sig_structure` for the given protected header and payload.
    /// - Parameters:
    ///   - protectedHeaderBytes: The original protected-header byte string, unchanged.
    ///   - payload: The mode-selected payload (embedded for attached, caller-supplied for detached).
    static func build(protectedHeaderBytes: Data, payload: Data) -> Data {
        // External AAD is empty for all supported ISO 18013-5 paths.
        let sigStructure = CBOR.array([
            .utf8String(signature1),
            .byteString([UInt8](protectedHeaderBytes)),
            .byteString([]),
            .byteString([UInt8](payload))
        ])

        return Data(sigStructure.encode())
    }
}
