import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable file_length
/// ISO/IEC TS 18013-6:2025 — DeviceEngagement conformance tests for the mdoc (device) side.
/// Reference: ISO/IEC 18013-5:2021, 8.2.1.1; 9.1.1.4; 9.1.5.2. RFC 7049 §2.1.
///
/// These tests validate the structure of the `DeviceEngagement` CBOR the mdoc produces (mDL_MS_DE_*),
/// covering device engagement via QR code / NFC ([DE-QR], [DE-NFC-SH], [DE-NFC-NH]).
///
/// CDDL (informative, ISO/IEC 18013-5:2021 §8.2.1.1):
/// DeviceEngagement = {
///   0: tstr,                          ; Version
///   1: Security,                      ; Security
///   ? 2: DeviceRetrievalMethods,      ; DeviceRetrievalMethods
///   ? 3: ServerRetrievalMethods,      ; ServerRetrievalMethods
///   * int => any                      ; RFU
/// }
/// Security = [
///   int,                              ; cipher suite identifier
///   EDeviceKeyBytes                   ; #6.24(bstr .cbor COSE_Key)
/// ]
/// DeviceRetrievalMethods = [+ DeviceRetrievalMethod]
/// DeviceRetrievalMethod = [
///   uint,                             ; type
///   uint,                             ; version
///   RetrievalOptions                  ; map
/// ]
///
/// Preconditions (A–C, per test):
/// A) Device engagement took place successfully.
/// B) The DeviceEngagement structure passed all Common_CBOR test cases (for DE_02 onwards).
/// C) The EDeviceKey data item passed all Common_CBOR test cases (for DE_09).
@Suite("DeviceEngagement Structure (mdoc)", .tags(.conformance))
struct DeviceEngagementStructureTest {

    // MARK: - mDL_MS_DE_01

    /// Validates the CBOR structure, canonicalization rules and uniqueness of pairs of the
    /// DeviceEngagement CBOR structure.
    ///
    /// Test procedure:
    /// 1. For the DeviceEngagement structure, perform all Common_CBOR test cases.
    ///
    /// Expected result:
    /// 1. All test cases pass (well-formed, canonical key ordering, unique keys).
    @Test("mDL_MS_DE_01: DeviceEngagement passes Common_CBOR validation (well-formed, canonical, unique keys)")
    func de01_commonCBORValidation() throws {
        let data = makeValidDeviceEngagementData()
        try validateCommonCBOR(data)
    }

    // MARK: - mDL_MS_DE_02

    /// Verifies that the major type of the DeviceEngagement structure is correct.
    ///
    /// Test procedure:
    /// 1. Verify the major type encoded on the first three bits of the first byte of the DeviceEngagement structure.
    ///
    /// Expected result:
    /// 1. The major type value is equal to 5 (i.e., a map).
    @Test("mDL_MS_DE_02: DeviceEngagement major type is 5 (map)")
    func de02_majorTypeIsMap() throws {
        let data = makeValidDeviceEngagementData()
        let firstByte = try #require([UInt8](data).first, "DeviceEngagement must not be empty")
        let majorType = firstByte >> 5
        #expect(majorType == 5, "DeviceEngagement must be a CBOR map (major type 5), got \(majorType)")
    }

    // MARK: - mDL_MS_DE_03

    /// Verifies that the number and value of data items in the DeviceEngagement structure are correct.
    ///
    /// Test procedure:
    /// 1. Verify the additional information encoded on the last five bits of the first byte of the DeviceEngagement map.
    /// 2. Verify that there are no unspecified data items present in the map.
    ///
    /// Expected results:
    /// 1. The value of the additional information (number of key-value pairs) is 2, 3, 4, 5 or 6.
    /// 2. The only key-value pairs present have the following properties:
    ///    — key 0 (uint) & value tstr (Version);
    ///    — key 1 (uint) & value array (Security);
    ///    — optionally key 2 (uint) & value array (DeviceRetrievalMethods);
    ///    — optionally key 3 (uint) & value map (ServerRetrievalMethods);
    ///    — zero or more RFU pairs: key nint (major type 1), value any major type.
    @Test("mDL_MS_DE_03: DeviceEngagement map has 2–6 pairs with correct keys and value types")
    func de03_mapStructureCorrect() throws {
        let data = makeValidDeviceEngagementData()
        let firstByte = try #require([UInt8](data).first)

        // 1. Additional information encodes the pair count (fits inline for small maps).
        let additionalInfo = firstByte & 0x1F
        #expect(
            (2...6).contains(additionalInfo),
            "DeviceEngagement map must contain 2–6 key-value pairs, got additional info \(additionalInfo)"
        )

        // 2. Verify key-value pairs.
        let pairs = try decodeDeviceEngagementMap(data)
        #expect((2...6).contains(pairs.count), "DeviceEngagement must contain 2–6 pairs, got \(pairs.count)")

        // Version: key 0 (uint) -> tstr
        let version = try #require(pairs[.unsignedInt(0)], "Version (key 0) must be present")
        guard case .utf8String = version else {
            Issue.record("Version (key 0) value must be a tstr (major type 3), got: \(version)")
            return
        }

        // Security: key 1 (uint) -> array
        let security = try #require(pairs[.unsignedInt(1)], "Security (key 1) must be present")
        guard case .array = security else {
            Issue.record("Security (key 1) value must be an array (major type 4), got: \(security)")
            return
        }

        // Optional DeviceRetrievalMethods: key 2 (uint) -> array
        if let retrieval = pairs[.unsignedInt(2)] {
            guard case .array = retrieval else {
                Issue.record("DeviceRetrievalMethods (key 2) value must be an array (major type 4), got: \(retrieval)")
                return
            }
        }

        // Optional ServerRetrievalMethods: key 3 (uint) -> map
        if let server = pairs[.unsignedInt(3)] {
            guard case .map = server else {
                Issue.record("ServerRetrievalMethods (key 3) value must be a map (major type 5), got: \(server)")
                return
            }
        }

        // No unspecified data items: positive keys must be within 0...3, any other keys must be nint (RFU).
        for key in pairs.keys {
            switch key {
            case .unsignedInt(let value):
                #expect((0...3).contains(value), "Unspecified positive key present: \(value)")
            case .negativeInt:
                // Allowed RFU: key major type = 1 (nint), value any major type.
                break
            default:
                Issue.record("DeviceEngagement key must be uint (0–3) or nint (RFU), got: \(key)")
            }
        }
    }

    // MARK: - mDL_MS_DE_04

    /// Verifies that the value of the "Version" data item in the DeviceEngagement structure is correct.
    ///
    /// Test procedure:
    /// 1. Verify the value of the key-value pair 0 (Version).
    ///
    /// Expected result:
    /// 1. The value equals 0x31 2E 30 ("1.0").
    @Test("mDL_MS_DE_04: DeviceEngagement Version value is \"1.0\" (0x312E30)")
    func de04_versionValueCorrect() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        guard case .utf8String(let version) = pairs[.unsignedInt(0)] else {
            Issue.record("Version (key 0) must be a tstr")
            return
        }
        #expect(version == "1.0", "Version must be \"1.0\", got \"\(version)\"")
        #expect(Array(version.utf8) == [0x31, 0x2E, 0x30], "Version UTF-8 bytes must be [0x31, 0x2E, 0x30]")
    }

    // MARK: - mDL_MS_DE_05

    /// Verifies that the number, major type and order of data items in the Security array are correct.
    ///
    /// Test procedure:
    /// 1. Verify the additional information on the first byte of the Security array value.
    /// 2. Verify that there are no unspecified data items present in the Security array.
    /// 3. Verify that the order of data items in the array is correct.
    ///
    /// Expected results:
    /// 1. The number of data items in the array is equal to 2.
    /// 2. The only data items present have major types: 0 or 1 (int, cipher suite identifier) and
    ///    6 (tagged item, EDeviceKeyBytes).
    /// 3. The order of data items is the same as in step 2.
    @Test("mDL_MS_DE_05: Security array has exactly 2 items in order [int, tagged]")
    func de05_securityArrayStructure() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        let security = try extractSecurityArray(from: pairs)

        // 1. Exactly 2 data items.
        #expect(security.count == 2, "Security array must contain exactly 2 items, got \(security.count)")

        // 2 & 3. Item 0: int (major type 0 uint, or 1 nint); Item 1: tagged (major type 6).
        let cipherSuite = try #require(security.first, "Security array must contain a cipher suite identifier")
        switch cipherSuite {
        case .unsignedInt, .negativeInt:
            break
        default:
            Issue.record("Security[0] (cipher suite identifier) must be an int (major type 0 or 1), got: \(cipherSuite)")
        }

        let eDeviceKeyBytes = try #require(security.count > 1 ? security[1] : nil, "Security array must contain EDeviceKeyBytes")
        guard case .tagged = eDeviceKeyBytes else {
            Issue.record("Security[1] (EDeviceKeyBytes) must be a tagged item (major type 6), got: \(eDeviceKeyBytes)")
            return
        }
    }

    // MARK: - mDL_MS_DE_06

    /// Verifies that the value of the cipher suite identifier data item in the Security array is correct.
    ///
    /// Test procedure:
    /// 1. Verify the value of the cipher suite identifier data item.
    ///
    /// Expected result:
    /// 1. The value of the cipher suite identifier data item is equal to 1.
    @Test("mDL_MS_DE_06: Security cipher suite identifier is 1")
    func de06_cipherSuiteIdentifier() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        let security = try extractSecurityArray(from: pairs)
        guard case .unsignedInt(let identifier) = security.first else {
            Issue.record("Security[0] cipher suite identifier must be a uint")
            return
        }
        #expect(identifier == 1, "Cipher suite identifier must be 1, got \(identifier)")
    }

    // MARK: - mDL_MS_DE_07

    /// Verifies the encoding of the EDeviceKeyBytes data item in the Security array.
    ///
    /// Test procedure:
    /// 1. Verify the additional information of the EDeviceKeyBytes data item.
    /// 2. Verify the tag value encoded in the second byte of the EDeviceKeyBytes data item.
    /// 3. Verify the major type of the encoded CBOR item.
    ///
    /// Expected results:
    /// 1. The additional information is 24 (tag value encoded on next 1 byte).
    /// 2. The tag value is equal to 24 (encoded CBOR data item).
    /// 3. The major type is equal to 2 (bstr).
    @Test("mDL_MS_DE_07: EDeviceKeyBytes is Tag(24) wrapping a bstr")
    func de07_eDeviceKeyBytesEncoding() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        let security = try extractSecurityArray(from: pairs)

        // Semantic verification via the decoded structure.
        let eDeviceKeyBytes = try #require(security.count > 1 ? security[1] : nil, "EDeviceKeyBytes must be present")
        guard case .tagged(let tag, let content) = eDeviceKeyBytes else {
            Issue.record("EDeviceKeyBytes must be a tagged item (major type 6)")
            return
        }
        // 1 & 2. Tag value 24 (SwiftCBOR represents it as .encodedCBORDataItem).
        #expect(tag == .encodedCBORDataItem, "EDeviceKeyBytes tag must be 24 (encodedCBORDataItem), got: \(tag)")
        // 3. Content is a bstr (major type 2).
        guard case .byteString = content else {
            Issue.record("EDeviceKeyBytes tag content must be a bstr (major type 2), got: \(content)")
            return
        }

        // Byte-level verification of the tag wire format: 0xD8 0x18, then a bstr header (major type 2).
        let bytes = [UInt8](data)
        let tagIndex = try #require(findTag24Index(in: bytes), "Could not locate Tag(24) in raw DeviceEngagement bytes")

        // 1. First byte: major type 6, additional info 24.
        let tagFirstByte = bytes[tagIndex]
        #expect(tagFirstByte >> 5 == 6, "Tag byte major type must be 6")
        #expect(tagFirstByte & 0x1F == 24, "Tag additional info must be 24 (1-byte tag value follows)")
        // 2. Second byte: tag value 24.
        #expect(bytes[tagIndex + 1] == 24, "Tag value must be 24 (encoded CBOR data item)")
        // 3. Third byte: bstr header (major type 2).
        #expect(bytes[tagIndex + 2] >> 5 == 2, "EDeviceKeyBytes content must be a bstr (major type 2)")
    }

    // MARK: - mDL_MS_DE_08

    /// Validates the CBOR structure, canonicalization rules and uniqueness of key-value pairs of the
    /// EDeviceKey CBOR data item within the EDeviceKeyBytes data item.
    ///
    /// Test procedure:
    /// 1. For the EDeviceKey data item in the EDeviceKeyBytes data item, perform all Common_CBOR test cases.
    ///
    /// Expected result:
    /// 1. All test cases pass.
    @Test("mDL_MS_DE_08: EDeviceKey (inside EDeviceKeyBytes) passes Common_CBOR validation")
    func de08_eDeviceKeyCommonCBOR() throws {
        let innerKeyBytes = try extractEDeviceKeyBytes()
        try validateCommonCBOR(Data(innerKeyBytes))
    }

    // MARK: - mDL_MS_DE_09

    /// Validates that the EDeviceKey data item is a valid COSE_Key, using either the compressed or
    /// uncompressed format.
    ///
    /// Test procedure:
    /// 1. For the EDeviceKey data item, perform all Common_COSEKey test cases.
    ///
    /// Expected result:
    /// 1. All test cases pass.
    ///
    /// The device produces an EC2 (uncompressed) COSE_Key: { 1: kty, -1: crv, -2: x (bstr), -3: y (bstr) }.
    @Test("mDL_MS_DE_09: EDeviceKey is a valid COSE_Key (EC2 uncompressed)")
    func de09_eDeviceKeyIsValidCOSEKey() throws {
        let innerKeyBytes = try extractEDeviceKeyBytes()
        let decoded = try #require(try CBOR.decode(innerKeyBytes), "EDeviceKey must be well-formed CBOR")
        guard case .map(let key) = decoded else {
            Issue.record("EDeviceKey must be a COSE_Key map (major type 5)")
            return
        }

        // kty (label 1) must be present. EC2 = 2, OKP = 1.
        let kty = try #require(key[.unsignedInt(1)], "COSE_Key must contain kty (label 1)")
        guard case .unsignedInt(let ktyValue) = kty else {
            Issue.record("kty (label 1) must be a uint, got: \(kty)")
            return
        }
        #expect(ktyValue == 1 || ktyValue == 2, "kty must be OKP (1) or EC2 (2), got \(ktyValue)")

        // crv (label -1) must be present and be a uint.
        let crv = try #require(key[.negativeInt(0)], "COSE_Key must contain crv (label -1)")
        guard case .unsignedInt = crv else {
            Issue.record("crv (label -1) must be a uint, got: \(crv)")
            return
        }

        // x-coordinate (label -2) must be a bstr for both EC2 and OKP.
        let xCoord = try #require(key[.negativeInt(1)], "COSE_Key must contain the x-coordinate (label -2)")
        guard case .byteString = xCoord else {
            Issue.record("x-coordinate (label -2) must be a bstr, got: \(xCoord)")
            return
        }

        // For the uncompressed EC2 format the y-coordinate (label -3) is a bstr.
        if ktyValue == 2 {
            let yCoord = try #require(key[.negativeInt(2)], "EC2 uncompressed COSE_Key must contain the y-coordinate (label -3)")
            guard case .byteString = yCoord else {
                Issue.record("y-coordinate (label -3) must be a bstr for uncompressed EC2, got: \(yCoord)")
                return
            }
        }
    }

    // MARK: - mDL_MS_DE_11

    /// Verifies that the number and major type of the data item(s) in the DeviceRetrievalMethods
    /// array are correct, in case device engagement took place via QR code. [DE-QR]
    ///
    /// Test procedure:
    /// 1. Verify the additional information on the first byte of the DeviceRetrievalMethods array value.
    /// 2. Verify that there are no unspecified data items present in the array.
    ///
    /// Expected results:
    /// 1. The number of data items in the array is at least 1 and at most 3.
    /// 2. The data item(s) present have major type: 4 (array, DeviceRetrievalMethod).
    @Test("mDL_MS_DE_11: DeviceRetrievalMethods array has 1–3 items, each an array")
    func de11_deviceRetrievalMethodsArray() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        guard case .array(let methods) = pairs[.unsignedInt(2)] else {
            Issue.record("DeviceRetrievalMethods (key 2) must be present and be an array for QR engagement")
            return
        }

        // 1. 1–3 items.
        #expect((1...3).contains(methods.count), "DeviceRetrievalMethods must have 1–3 items, got \(methods.count)")

        // 2. Every item is an array (major type 4).
        for (index, method) in methods.enumerated() {
            guard case .array = method else {
                Issue.record("DeviceRetrievalMethods[\(index)] must be an array (major type 4), got: \(method)")
                return
            }
        }
    }

    // MARK: - mDL_MS_DE_12

    /// Verifies that the number, major type and order of data items in each DeviceRetrievalMethod
    /// array are correct, in case device engagement took place via QR code. [DE-QR]
    ///
    /// Test procedure (for each DeviceRetrievalMethod array):
    /// 1. Verify the additional information on the first byte.
    /// 2. Verify that there are no unspecified data items present in the array.
    /// 3. Verify that the order of data items in the array is correct.
    /// 4. Verify the value of the Type data item.
    /// 5. Verify that the Type value is unique among all DeviceRetrievalMethod arrays.
    ///
    /// Expected results:
    /// 1. The number of data items in the array is 2 or 3.
    /// 2. The only data items present have major types: 0 (uint, Type), 0 (uint, Version), 5 (map, RetrievalOptions).
    /// 3. The order is the same as in step 2.
    /// 4. The Type value is equal to 1, 2, or 3.
    /// 5. The Type value is unique across all DeviceRetrievalMethod arrays.
    @Test("mDL_MS_DE_12: each DeviceRetrievalMethod is [Type, Version, RetrievalOptions] with unique Type in {1,2,3}")
    func de12_deviceRetrievalMethodStructure() throws {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        guard case .array(let methods) = pairs[.unsignedInt(2)] else {
            Issue.record("DeviceRetrievalMethods (key 2) must be present and be an array for QR engagement")
            return
        }

        var seenTypes = Set<UInt64>()
        for (index, method) in methods.enumerated() {
            guard case .array(let items) = method else {
                Issue.record("DeviceRetrievalMethods[\(index)] must be an array")
                return
            }

            // 1. 2 or 3 items.
            #expect(
                items.count == 2 || items.count == 3,
                "DeviceRetrievalMethod[\(index)] must have 2 or 3 items, got \(items.count)"
            )

            // 2 & 3. Order/major types: [uint Type, uint Version, (map RetrievalOptions)].
            guard case .unsignedInt(let type) = items.first else {
                Issue.record("DeviceRetrievalMethod[\(index)][0] (Type) must be a uint")
                return
            }
            guard items.count > 1, case .unsignedInt = items[1] else {
                Issue.record("DeviceRetrievalMethod[\(index)][1] (Version) must be a uint")
                return
            }
            if items.count == 3 {
                guard case .map = items[2] else {
                    Issue.record("DeviceRetrievalMethod[\(index)][2] (RetrievalOptions) must be a map (major type 5)")
                    return
                }
            }

            // 4. Type value in {1, 2, 3}.
            #expect((1...3).contains(type), "DeviceRetrievalMethod[\(index)] Type must be 1, 2, or 3, got \(type)")

            // 5. Type unique across methods.
            #expect(!seenTypes.contains(type), "DeviceRetrievalMethod Type \(type) is duplicated across methods")
            seenTypes.insert(type)
        }
    }

    // MARK: - Helpers

    /// Extracts the inner EDeviceKey CBOR bytes carried inside the Security array's
    /// EDeviceKeyBytes `#6.24(bstr .cbor COSE_Key)` element.
    private func extractEDeviceKeyBytes() throws -> [UInt8] {
        let data = makeValidDeviceEngagementData()
        let pairs = try decodeDeviceEngagementMap(data)
        let security = try extractSecurityArray(from: pairs)
        guard security.count > 1,
              case .tagged(.encodedCBORDataItem, .byteString(let innerBytes)) = security[1] else {
            Issue.record("EDeviceKeyBytes must be Tag(24, bstr(COSE_Key))")
            return []
        }
        return innerBytes
    }

    /// Finds the byte index of the first Tag(24) item (0xD8 0x18) in a CBOR byte array.
    private func findTag24Index(in bytes: [UInt8]) -> Int? {
        guard bytes.count > 1 else { return nil }
        for i in 0..<(bytes.count - 1) where bytes[i] == 0xD8 && bytes[i + 1] == 0x18 {
            return i
        }
        return nil
    }
}

// swiftlint:enable file_length
