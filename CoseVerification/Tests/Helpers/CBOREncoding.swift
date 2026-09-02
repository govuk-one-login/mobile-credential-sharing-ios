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
