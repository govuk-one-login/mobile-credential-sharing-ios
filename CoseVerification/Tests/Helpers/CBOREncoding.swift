import Foundation

/// Encodes a byte array as a CBOR byte string (major type 2).
func cborByteString(_ bytes: [UInt8]) -> [UInt8] {
    let count = bytes.count
    var header: [UInt8]
    if count <= 23 {
        header = [UInt8(0x40 + count)]
    } else if count <= 255 {
        header = [0x58, UInt8(count)]
    } else if count <= 65535 {
        header = [0x59, UInt8(count >> 8), UInt8(count & 0xFF)]
    } else {
        header = [0x5A,
                  UInt8((count >> 24) & 0xFF),
                  UInt8((count >> 16) & 0xFF),
                  UInt8((count >> 8) & 0xFF),
                  UInt8(count & 0xFF)]
    }
    return header + bytes
}

/// The COSE_Sign1 payload element: a byte string when attached, CBOR null (`0xF6`) when detached.
enum CosePayloadElement {
    case attached([UInt8])
    case detached

    var bytes: [UInt8] {
        switch self {
        case .attached(let payload): return cborByteString(payload)
        case .detached: return [0xF6]
        }
    }
}

/// Assembles an untagged four-element COSE_Sign1 CBOR array:
/// `[protected_bstr, unprotected_map, payload, signature_bstr]`.
///
/// - Parameters:
///   - protectedHeader: Raw protected-header bytes (wrapped as a byte string).
///   - unprotectedHeader: Raw CBOR bytes for the unprotected map (defaults to empty map `0xA0`).
///   - payload: The payload element (attached byte string or detached null).
///   - signature: Raw signature bytes (wrapped as a byte string).
func cborCoseSign1(
    protectedHeader: [UInt8],
    unprotectedHeader: [UInt8] = [0xA0],
    payload: CosePayloadElement,
    signature: [UInt8]
) -> Data {
    Data([0x84]
        + cborByteString(protectedHeader)
        + unprotectedHeader
        + payload.bytes
        + cborByteString(signature))
}
