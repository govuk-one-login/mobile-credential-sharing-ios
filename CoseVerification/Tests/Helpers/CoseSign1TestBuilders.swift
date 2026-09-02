import Foundation

/// Builds a minimal valid COSE_Sign1 CBOR byte array with an attached payload and ES256 algorithm.
///
/// Structure: [protected_header_bytes, unprotected_header_map, payload_bytes, signature_bytes]
///
/// The protected header is a byte string containing a CBOR map: {1: -7} (alg: ES256)
/// The unprotected header is an empty CBOR map: {}
/// The payload is a byte string: the given bytes
/// The signature is a byte string: 64 bytes of 0xAA (placeholder)
func makeValidAttachedCoseSign1(
    protectedHeaderBytes: [UInt8]? = nil,
    unprotectedHeader: [UInt8]? = nil,
    payload: [UInt8] = [0x01, 0x02, 0x03],
    signature: [UInt8]? = nil
) -> Data {
    // Protected header: CBOR map {1: -7} encoded as bytes: A1 01 26
    // A1 = map(1 pair), 01 = unsigned int 1, 26 = negative int -7 (encoded as ~6)
    let protHeader = protectedHeaderBytes ?? [0xA1, 0x01, 0x26]

    // Wrap protected header in a byte string
    let protHeaderBstr = cborByteString(protHeader)

    // Unprotected header: empty map {} = A0
    let unprotHeader = unprotectedHeader ?? [0xA0]

    // Payload: byte string
    let payloadBstr = cborByteString(payload)

    // Signature: 64-byte placeholder
    let sig = signature ?? [UInt8](repeating: 0xAA, count: 64)
    let sigBstr = cborByteString(sig)

    // Wrap in a 4-element array: 84 = array(4)
    var result: [UInt8] = [0x84]
    result.append(contentsOf: protHeaderBstr)
    result.append(contentsOf: unprotHeader)
    result.append(contentsOf: payloadBstr)
    result.append(contentsOf: sigBstr)

    return Data(result)
}

/// Builds a minimal valid detached COSE_Sign1 (payload is CBOR null).
func makeValidDetachedCoseSign1(
    protectedHeaderBytes: [UInt8]? = nil,
    unprotectedHeader: [UInt8]? = nil,
    signature: [UInt8]? = nil
) -> Data {
    let protHeader = protectedHeaderBytes ?? [0xA1, 0x01, 0x26]
    let protHeaderBstr = cborByteString(protHeader)
    let unprotHeader = unprotectedHeader ?? [0xA0]
    let sig = signature ?? [UInt8](repeating: 0xAA, count: 64)
    let sigBstr = cborByteString(sig)

    // Payload is CBOR null: F6
    var result: [UInt8] = [0x84]
    result.append(contentsOf: protHeaderBstr)
    result.append(contentsOf: unprotHeader)
    result.append(0xF6) // null
    result.append(contentsOf: sigBstr)

    return Data(result)
}
