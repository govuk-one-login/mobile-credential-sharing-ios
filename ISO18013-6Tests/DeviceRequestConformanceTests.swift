import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable file_length

extension Testing.Tag {
    @Testing.Tag static var conformance: Self
}

/// ISO/IEC TS 18013-6:2025 — DeviceRequest conformance tests for mdoc reader
/// Reference: ISO/IEC 18013-5:2021, 8.3.2.1.2.1
///
/// CDDL (informative):
/// DeviceRequest = {
///   "version" : tstr,           ; "1.0"
///   "docRequests" : [+ DocRequest]
/// }
///
/// DocRequest = {
///   "itemsRequest" : ItemsRequestBytes,
///   ? "readerAuth" : ReaderAuth
/// }
///
/// ItemsRequestBytes = #6.24(bstr .cbor ItemsRequest)
///
/// Preconditions (A–D):
/// A) Device engagement took place successfully.
/// B) The mdoc reader sent a SessionEstablishment message, containing an encrypted DeviceRequest.
/// C) The DeviceRequest was successfully decrypted.
/// D) The DeviceRequest structure passed all Common_CBOR test cases (for DR_02 onwards).
@Suite("DeviceRequest Conformance", .tags(.conformance))
struct DeviceRequestConformanceTests {

    // MARK: - Test Vectors
    
    private func validData() throws -> Data {
        /// Valid DeviceRequest generated from the verifier's own ISO models:
        /// DeviceRequest { "version": "1.0", "docRequests": [DocRequest { "itemsRequest": Tag(24, bstr(ItemsRequest)) }] }
        /// ItemsRequest requests org.iso.18013.5.1.mDL / org.iso.18013.5.1 { given_name: false, family_name: true }.
        try makeValidDeviceRequestData()
    }

    private func dataWithReaderAuth() throws -> Data {
        /// DeviceRequest generated from the verifier models with a readerAuth COSE_Sign1 spliced into the DocRequest:
        /// DocRequest { "readerAuth": [bstr, {}, null, bstr(64)], "itemsRequest": Tag(24, bstr(ItemsRequest)) }
        try makeDeviceRequestDataWithReaderAuth()
    }

    // MARK: - mDLR_MS_DR_01

    /// Validates the CBOR structure, canonicalization rules and uniqueness of key-value pairs
    /// of the DeviceRequest CBOR structure.
    ///
    /// Test procedure:
    /// 1. For the DeviceRequest structure, perform all Common_CBOR test cases specified in Appendix 1, 1.1.
    ///
    /// Expected result:
    /// 1. All test cases pass (well-formed, canonical key ordering, unique keys).
    @Test("mDLR_MS_DR_01: DeviceRequest passes Common_CBOR validation (well-formed, canonical, unique keys)")
    func dr01_commonCBORValidation() throws {
        let data = try validData()
        try validateCommonCBOR(data)
    }

    @Test("mDLR_MS_DR_01: DeviceRequest with readerAuth passes Common_CBOR validation")
    func dr01_commonCBORValidationWithReaderAuth() throws {
        let data = try dataWithReaderAuth()
        try validateCommonCBOR(data)
    }

    // MARK: - mDLR_MS_DR_02

    /// Verifies that the major type of the DeviceRequest structure is correct.
    ///
    /// Test procedure:
    /// 1. Verify the major type encoded on the first three bits of the first byte of the DeviceRequest CBOR structure.
    ///
    /// Expected result:
    /// 1. The major type value is equal to 5 (i.e., a map).
    @Test("mDLR_MS_DR_02: DeviceRequest major type is 5 (map)")
    func dr02_majorTypeIsMap() throws {
        let data = try validData()
        let firstByte = data[0]
        let majorType = firstByte >> 5
        #expect(majorType == 5, "DeviceRequest must be a CBOR map (major type 5), got \(majorType)")
    }

    // MARK: - mDLR_MS_DR_03

    /// Verifies that the number and value of data items in the DeviceRequest structure are correct.
    ///
    /// Test procedure:
    /// 1. Verify the additional information encoded on the last five bits of the first byte of the DeviceRequest map.
    /// 2. Verify that there are no unspecified data items present in the map.
    ///
    /// Expected results:
    /// 1. The value of the additional information (encoding the number of key-value pairs in the map) is 2.
    /// 2. The only key-value pairs present have the following keys and values:
    ///    — key major type = 3 (tstr), key value = "version" & value major type = 3 (tstr);
    ///    — key major type = 3 (tstr), key value = "docRequests" & value major type = 4 (array).
    @Test("mDLR_MS_DR_03: DeviceRequest map contains exactly 2 pairs with correct keys and value types")
    func dr03_mapStructureCorrect() throws {
        let data = try validData()
        let firstByte = data[0]

        // 1. Additional information == 2 (two key-value pairs)
        let additionalInfo = firstByte & 0x1F
        #expect(additionalInfo == 2, "DeviceRequest map must contain 2 key-value pairs, got \(additionalInfo)")

        // 2. Verify key-value pairs
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded else {
            Issue.record("Expected CBOR map at top level")
            return
        }

        // Check "version" key exists with tstr value (major type 3)
        let versionValue = try #require(pairs[.utf8String("version")], "\"version\" key must be present")
        guard case .utf8String = versionValue else {
            Issue.record("\"version\" value must be a tstr (major type 3), got: \(versionValue)")
            return
        }

        // Check "docRequests" key exists with array value (major type 4)
        let docRequestsValue = try #require(pairs[.utf8String("docRequests")], "\"docRequests\" key must be present")
        guard case .array = docRequestsValue else {
            Issue.record("\"docRequests\" value must be an array (major type 4), got: \(docRequestsValue)")
            return
        }

        // Verify no other keys are present
        #expect(pairs.count == 2, "DeviceRequest must contain only \"version\" and \"docRequests\" keys")
    }

    // MARK: - mDLR_MS_DR_04

    /// Verifies that the value of the "version" key-value pair in the DeviceRequest structure is correct.
    ///
    /// Test procedure:
    /// 1. Verify the value of the "version" key-value pair.
    ///
    /// Expected result:
    /// 1. The value equals 0x31 2E 30 ("1.0").
    @Test("mDLR_MS_DR_04: DeviceRequest version value is \"1.0\" (0x312E30)")
    func dr04_versionValueCorrect() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .utf8String(let version) = pairs[.utf8String("version")] else {
            Issue.record("Expected map with \"version\" tstr key")
            return
        }

        // Verify the string value
        #expect(version == "1.0", "version must be \"1.0\", got \"\(version)\"")

        // Also verify the raw byte encoding: 0x31 0x2E 0x30
        let versionBytes = Array(version.utf8)
        #expect(versionBytes == [0x31, 0x2E, 0x30], "version UTF-8 bytes must be [0x31, 0x2E, 0x30]")
    }

    // MARK: - mDLR_MS_DR_05

    /// Verifies that the number and order of data items in the "docRequests" data item
    /// in the DeviceRequest structure are correct.
    ///
    /// Test procedure:
    /// 1. Verify the additional information encoded on the last five bits of the first byte
    ///    of the value of the "docRequests" key-value pair.
    /// 2. Verify that there are no unspecified data items present in the array.
    ///
    /// Expected results:
    /// 1. The value of the additional information (i.e. the number of data items in the array) is at least 1.
    /// 2. All data items present have the following major type: 5 (map, DocRequest).
    @Test("mDLR_MS_DR_05: docRequests array contains at least 1 item, all items are maps")
    func dr05_docRequestsArrayValid() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .array(let docRequests) = pairs[.utf8String("docRequests")] else {
            Issue.record("Expected map with \"docRequests\" array")
            return
        }

        // 1. At least 1 item
        #expect(docRequests.count >= 1, "docRequests must contain at least 1 DocRequest, got \(docRequests.count)")

        // 2. All items are maps (major type 5)
        for (index, docRequest) in docRequests.enumerated() {
            guard case .map = docRequest else {
                Issue.record("docRequests[\(index)] must be a map (major type 5), got: \(docRequest)")
                return
            }
        }

        // Also verify at the byte level: locate the docRequests array's first byte
        // by structurally walking the CBOR, rather than assuming fixed offsets.
        let bytes = [UInt8](data)
        let docRequestsArrayByte = try #require(
            docRequestsArrayFirstByte(in: bytes),
            "Could not locate the docRequests array in the raw DeviceRequest bytes"
        )
        let arrayMajorType = docRequestsArrayByte >> 5
        let arrayAdditionalInfo = docRequestsArrayByte & 0x1F
        #expect(arrayMajorType == 4, "docRequests value must be array (major type 4)")
        #expect(arrayAdditionalInfo >= 1, "docRequests array must have at least 1 element")
    }

    // MARK: - mDLR_MS_DR_06

    /// Verifies that the number and value of data items in the DocRequest map(s)
    /// in the DeviceRequest structure are correct.
    ///
    /// Test procedure (for all DocRequest maps):
    /// 1. Verify the additional information encoded on the last five bits of the first byte.
    /// 2. Verify that there are no unspecified data items present in the map.
    ///
    /// Expected results:
    /// 1. The value of the additional information (encoding the number of key-value pairs in the map) is 1 or 2.
    /// 2. The only key-value pairs present have the following properties:
    ///    — mandatory: key major type = 3 (tstr), key value = "itemsRequest" & value major type = 6 (tagged item);
    ///    — optionally: key major type = 3 (tstr), key value = "readerAuth" & value major type = 4 (array).
    @Test("mDLR_MS_DR_06: DocRequest map contains 1 pair (itemsRequest only)")
    func dr06_docRequestMapWithItemsRequestOnly() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .array(let docRequests) = pairs[.utf8String("docRequests")] else {
            Issue.record("Expected DeviceRequest structure")
            return
        }

        for (index, docRequest) in docRequests.enumerated() {
            guard case .map(let docReqPairs) = docRequest else {
                Issue.record("docRequests[\(index)] must be a map")
                return
            }

            // 1. Number of pairs is 1 or 2
            #expect(
                docReqPairs.count == 1 || docReqPairs.count == 2,
                "DocRequest[\(index)] must have 1 or 2 key-value pairs, got \(docReqPairs.count)"
            )

            // 2a. Mandatory: "itemsRequest" -> tagged item (major type 6)
            let itemsRequestValue = try #require(
                docReqPairs[.utf8String("itemsRequest")],
                "DocRequest[\(index)] must contain \"itemsRequest\" key"
            )
            guard case .tagged = itemsRequestValue else {
                Issue.record("DocRequest[\(index)] \"itemsRequest\" value must be a tagged item (major type 6), got: \(itemsRequestValue)")
                return
            }

            // 2b. Check no unspecified keys
            let allowedKeys: Set<String> = ["itemsRequest", "readerAuth"]
            for key in docReqPairs.keys {
                if case .utf8String(let keyStr) = key {
                    #expect(allowedKeys.contains(keyStr), "DocRequest[\(index)] contains unspecified key: \"\(keyStr)\"")
                } else {
                    Issue.record("DocRequest[\(index)] key must be tstr, got: \(key)")
                }
            }
        }
    }

    @Test("mDLR_MS_DR_06: DocRequest map contains 2 pairs (itemsRequest + readerAuth)")
    func dr06_docRequestMapWithReaderAuth() throws {
        let data = try dataWithReaderAuth()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .array(let docRequests) = pairs[.utf8String("docRequests")] else {
            Issue.record("Expected DeviceRequest structure")
            return
        }

        for (index, docRequest) in docRequests.enumerated() {
            guard case .map(let docReqPairs) = docRequest else {
                Issue.record("docRequests[\(index)] must be a map")
                return
            }

            // 1. This vector has 2 pairs
            #expect(docReqPairs.count == 2, "DocRequest[\(index)] with readerAuth must have 2 key-value pairs")

            // 2a. Mandatory: "itemsRequest" -> tagged item (major type 6)
            let itemsRequestValue = try #require(
                docReqPairs[.utf8String("itemsRequest")],
                "DocRequest[\(index)] must contain \"itemsRequest\" key"
            )
            guard case .tagged = itemsRequestValue else {
                Issue.record("\"itemsRequest\" value must be a tagged item (major type 6)")
                return
            }

            // 2b. Optional: "readerAuth" -> array (major type 4) (COSE_Sign1)
            let readerAuthValue = try #require(
                docReqPairs[.utf8String("readerAuth")],
                "DocRequest[\(index)] must contain \"readerAuth\" key in this vector"
            )
            guard case .array = readerAuthValue else {
                Issue.record("\"readerAuth\" value must be an array (major type 4, COSE_Sign1), got: \(readerAuthValue)")
                return
            }
        }
    }

    // MARK: - mDLR_MS_DR_07

    /// Verifies the encoding of the ItemsRequestBytes data item(s) in the DeviceRequest structure.
    ///
    /// Test procedure (for all DocRequest maps):
    /// 1. Verify the additional information encoded on the first byte of the value of the ItemsRequestBytes data item.
    /// 2. Verify the tag value encoded on the second byte of the value of the ItemsRequestBytes data item.
    /// 3. Verify the major type of the encoded CBOR item in the value of the ItemsRequestBytes data item.
    ///
    /// Expected results:
    /// 1. The value of the additional information is 24 (meaning tag value is encoded on next 1 byte).
    /// 2. The tag value is equal to 24 (encoded CBOR data item).
    /// 3. The major type is equal to 2 (bstr).
    @Test("mDLR_MS_DR_07: ItemsRequestBytes is Tag(24) wrapping a bstr (encoded CBOR)")
    func dr07_itemsRequestBytesEncoding() throws {
        let data = try validData()
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let pairs) = decoded,
              case .array(let docRequests) = pairs[.utf8String("docRequests")] else {
            Issue.record("Expected DeviceRequest structure")
            return
        }

        for (index, docRequest) in docRequests.enumerated() {
            guard case .map(let docReqPairs) = docRequest else {
                Issue.record("docRequests[\(index)] must be a map")
                return
            }

            let itemsRequestValue = try #require(
                docReqPairs[.utf8String("itemsRequest")],
                "DocRequest[\(index)] must contain \"itemsRequest\""
            )

            // Verify at the semantic level via SwiftCBOR decoded structure
            guard case .tagged(let tag, let tagContent) = itemsRequestValue else {
                Issue.record("ItemsRequestBytes must be a tagged item (major type 6)")
                return
            }

            // 1 & 2. Tag value == 24 (CBOR tag for encoded CBOR data item)
            // In the wire format: first byte = 0xD8 (major type 6, additional info 24 meaning "1-byte tag follows")
            //                     second byte = 0x18 (tag value 24)
            // SwiftCBOR represents Tag 24 as .encodedCBORDataItem
            #expect(
                tag == .encodedCBORDataItem,
                "ItemsRequestBytes tag must be 24 (encodedCBORDataItem), got: \(tag)"
            )

            // 3. Tag content must be bstr (major type 2)
            guard case .byteString(let innerBytes) = tagContent else {
                Issue.record("Tag 24 content must be a bstr (major type 2), got: \(tagContent)")
                return
            }

            // Additionally verify the inner bstr contains valid CBOR
            let innerDecoded = try #require(
                try CBOR.decode(innerBytes),
                "Inner bytes of ItemsRequestBytes must be valid CBOR"
            )
            // The inner structure should be a map (ItemsRequest)
            guard case .map = innerDecoded else {
                Issue.record("Inner CBOR of ItemsRequestBytes must decode to a map (ItemsRequest)")
                return
            }
        }
    }

    @Test("mDLR_MS_DR_07: ItemsRequestBytes raw byte encoding — Tag 24 wire format verification")
    func dr07_itemsRequestBytesRawEncoding() throws {
        let data = try validData()
        let bytes = [UInt8](data)

        // Find the Tag(24, bstr) sequence in the raw bytes
        // Tag 24 is encoded as: 0xD8 0x18 (major type 6 = 0xC0, additional info 24 = 0x18 → 0xD8; then tag value 0x18 = 24)
        let tagByteIndex = try #require(
            findTaggedItemIndex(in: bytes),
            "Could not locate Tag(24) in raw DeviceRequest bytes"
        )

        // 1. First byte of tagged item: 0xD8
        //    Major type = 6 (110xxxxx), additional info = 24 (0x18)
        //    This means "tag value is encoded in the next 1 byte"
        let tagFirstByte = bytes[tagByteIndex]
        let tagMajorType = tagFirstByte >> 5
        let tagAdditionalInfo = tagFirstByte & 0x1F
        #expect(tagMajorType == 6, "Tag byte major type must be 6")
        #expect(tagAdditionalInfo == 24, "Tag additional info must be 24 (1-byte tag value follows)")

        // 2. Second byte: tag value = 24 (0x18)
        let tagValue = bytes[tagByteIndex + 1]
        #expect(tagValue == 24, "Tag value must be 24 (encoded CBOR data item)")

        // 3. Third byte onwards: bstr (major type 2)
        let bstrByte = bytes[tagByteIndex + 2]
        let bstrMajorType = bstrByte >> 5
        #expect(bstrMajorType == 2, "ItemsRequestBytes content must be bstr (major type 2)")
    }

    // MARK: - Helpers

    /// Finds the first byte of the "docRequests" array value in raw CBOR.
    ///
    /// Locates the encoded text-string key `"docRequests"` (0x6B followed by its 11 UTF-8 bytes)
    /// and returns the byte immediately after it — the first byte of that key's value. This does
    /// not assume any fixed offset or key ordering, so it stays correct even if the encoder changes
    /// map key order.
    private func docRequestsArrayFirstByte(in bytes: [UInt8]) -> UInt8? {
        // Encoded key: tstr(11) header (0x60 | 11 = 0x6B) + UTF-8 bytes of "docRequests".
        let keyBytes: [UInt8] = [0x6B] + Array("docRequests".utf8)
        guard bytes.count > keyBytes.count else { return nil }
        for start in 0...(bytes.count - keyBytes.count - 1) where Array(bytes[start..<start + keyBytes.count]) == keyBytes {
            return bytes[start + keyBytes.count]
        }
        return nil
    }

    /// Finds the byte index of the first Tag(24) item (0xD8 0x18) in the CBOR byte array.
    private func findTaggedItemIndex(in bytes: [UInt8]) -> Int? {
        for i in 0..<(bytes.count - 1) {
            if bytes[i] == 0xD8 && bytes[i + 1] == 0x18 {
                return i
            }
        }
        return nil
    }
}

// swiftlint:enable file_length
