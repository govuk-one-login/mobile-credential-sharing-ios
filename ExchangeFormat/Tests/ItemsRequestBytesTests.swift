import ExchangeFormat
import Foundation
import SwiftCBOR
import Testing

struct ItemsRequestBytesTests {

    // tag(24), bstr(1) [0x00] — wraps one complete item (unsigned int 0).
    private static let minimalTag24 = Data([0xD8, 0x18, 0x41, 0x00])

    @Test("Accepts a valid minimal Tag 24 value")
    func validMinimalTag24() throws {
        let sut = try ItemsRequestBytes(from: Self.minimalTag24)
        #expect(sut.bytes == Self.minimalTag24)
    }

    @Test("Accepts a Tag 24 wrapping a CBOR map (representative ItemsRequest)")
    func validTag24WithMap() throws {
        let innerMap = CBOR.map([.utf8String("docType"): .utf8String("org.iso.18013.5.1.mDL")])
        let tag24 = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))
        let tag24Bytes = Data(tag24.encode())

        let sut = try ItemsRequestBytes(from: tag24Bytes)
        #expect(sut.bytes == tag24Bytes)
    }

    @Test("Rejects empty data")
    func emptyData() {
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try ItemsRequestBytes(from: Data())
        }
    }

    @Test("Rejects a bare CBOR value that is not Tag 24")
    func bareValue() {
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try ItemsRequestBytes(from: Data([0x00]))
        }
    }

    @Test("Accepts Tag 24 with an empty embedded byte string (content is opaque)")
    func emptyEmbedded() throws {
        // tag(24), bstr(0). The embedded item is not inspected at construction.
        let data = Data([0xD8, 0x18, 0x40])
        let sut = try ItemsRequestBytes(from: data)
        #expect(sut.bytes == data)
    }

    @Test("Rejects a tag that is not Tag 24")
    func wrongTag() {
        let tagged = CBOR.tagged(CBOR.Tag(rawValue: 0), .byteString([0x00]))
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try ItemsRequestBytes(from: Data(tagged.encode()))
        }
    }

    @Test("Rejects Tag 24 wrapping a non-byte-string value")
    func tag24WrappingNonByteString() {
        let tagged = CBOR.tagged(.encodedCBORDataItem, .unsignedInt(1))
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try ItemsRequestBytes(from: Data(tagged.encode()))
        }
    }

    @Test("Owns an independent copy of its bytes")
    func ownsIndependentCopy() throws {
        var mutable = Self.minimalTag24
        let sut = try ItemsRequestBytes(from: mutable)
        mutable[0] = 0x00
        #expect(sut.bytes == Self.minimalTag24)
    }
}
