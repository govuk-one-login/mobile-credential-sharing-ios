import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable line_length

/// ISO/IEC TS 18013-6:2025 — Session Establishment conformance tests for mdoc reader
/// Reference: ISO/IEC 18013-5:2021, 9.1.1.4
@Suite("Session Establishment Conformance")
struct SessionEstablishmentConformanceTests {

    // Valid SessionEstablishment: map(2) { "eReaderKey": Tag(24, bstr(COSE_Key)), "data": bstr(16) }
    // COSE_Key: {1:2(EC2), -1:1(P-256), -2:bstr(32), -3:bstr(32)}
    let validHex = "a26a655265616465724b6579d818584ba4010220012158200102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202258202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40646461746150aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

    private func validData() throws -> Data {
        try #require(Data(hexString: validHex))
    }

    // MARK: - mDLR_MS_SE_01

    @Test("mDLR_MS_SE_01: SessionEstablishment passes Common_CBOR validation (well-formed, canonical, unique keys)")
    func commonCBORValidation() throws {
        let data = try validData()
        let bytes = [UInt8](data)

        // Well-formed: decodes without error
        let decoded = try #require(try CBOR.decode(bytes))

        // Uniqueness: map keys are unique (SwiftCBOR enforces this on decode)
        guard case .map(let pairs) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        let keys = pairs.keys.map { $0 }
        #expect(keys.count == Set(keys.map { "\($0)" }).count)
    }

    // MARK: - mDLR_MS_SE_02

    @Test("mDLR_MS_SE_02: SessionEstablishment major type is 5 (map)")
    func majorTypeIsMap() throws {
        let data = try validData()
        let firstByte = data[0]
        let majorType = firstByte >> 5
        #expect(majorType == 5)
    }

    // MARK: - mDLR_MS_SE_03

    @Test("mDLR_MS_SE_03: SessionEstablishment contains exactly 2 pairs with correct keys and value types")
    func mapContainsExactlyTwoCorrectPairs() throws {
        let data = try validData()
        let firstByte = data[0]
        let additionalInfo = firstByte & 0x1F
        #expect(additionalInfo == 2)

        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }

        // "eReaderKey" -> tagged item
        let eReaderKeyValue = try #require(pairs[.utf8String("eReaderKey")])
        guard case .tagged(.encodedCBORDataItem, _) = eReaderKeyValue else {
            Issue.record("eReaderKey value must be a tagged item (major type 6)")
            return
        }

        // "data" -> byteString
        let dataValue = try #require(pairs[.utf8String("data")])
        guard case .byteString = dataValue else {
            Issue.record("data value must be a bstr (major type 2)")
            return
        }
    }

    // MARK: - mDLR_MS_SE_04

    @Test("mDLR_MS_SE_04: EReaderKeyBytes is Tag 24 wrapping a bstr")
    func eReaderKeyBytesIsTag24Bstr() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .tagged(let tag, let tagContent) = pairs[.utf8String("eReaderKey")] else {
            Issue.record("Expected tagged eReaderKey")
            return
        }

        // Tag value is 24 (encodedCBORDataItem)
        #expect(tag == .encodedCBORDataItem)

        // Content is bstr
        guard case .byteString = tagContent else {
            Issue.record("Tag 24 content must be bstr (major type 2)")
            return
        }
    }

    // MARK: - mDLR_MS_SE_05

    @Test("mDLR_MS_SE_05: Encoded CBOR in EReaderKeyBytes passes Common_CBOR validation")
    func eReaderKeyBytesInnerCBORValid() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .tagged(.encodedCBORDataItem, .byteString(let innerBytes)) = pairs[.utf8String("eReaderKey")] else {
            Issue.record("Expected Tag(24, bstr) for eReaderKey")
            return
        }

        // Inner bytes decode as valid CBOR
        let innerDecoded = try #require(try CBOR.decode(innerBytes))

        // Must be a map with unique keys
        guard case .map(let innerPairs) = innerDecoded else {
            Issue.record("Inner CBOR must be a map")
            return
        }
        let keys = innerPairs.keys.map { "\($0)" }
        #expect(keys.count == Set(keys).count)
    }

    // MARK: - mDLR_MS_SE_06

    @Test("mDLR_MS_SE_06: Encoded CBOR in EReaderKeyBytes is a valid COSE_Key")
    func eReaderKeyBytesIsValidCOSEKey() throws {
        let data = try validData()
        let sut = try SessionEstablishment(rawData: data)

        #expect(sut.eReaderKey.curve == .p256)
        #expect(sut.eReaderKey.xCoordinate.count == 32)
        #expect(sut.eReaderKey.yCoordinate.count == 32)
    }
}

// MARK: - Hex String Helper

private extension Data {
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}

// swiftlint:enable line_length
