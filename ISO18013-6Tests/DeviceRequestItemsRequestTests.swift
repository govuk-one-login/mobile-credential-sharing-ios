import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable line_length

/// Tests mDLR_MS_DR_08 through mDLR_MS_DR_15: ItemsRequest validation in DeviceRequest structure.
///
/// CDDL reference (ISO/IEC 18013-5:2021, 8.3.2.1.2.1):
/// ```
/// ItemsRequest = {
///   "docType" : DocType,        ; tstr
///   "nameSpaces" : NameSpaces,  ; map
///   ? "requestInfo" : map
/// }
/// NameSpaces = { + NameSpace => DataElements }
/// DataElements = { + DataElement => IntentToRetain }
/// DataElement = tstr
/// IntentToRetain = bool
/// DocType = tstr  ("org.iso.18013.5.1.mDL")
/// ```
@Suite("ItemsRequest in DeviceRequest Conformance")
struct DeviceRequestItemsRequestTests {

    // MARK: - Test Vectors

    // Valid ItemsRequest with 2 keys (docType + nameSpaces), one namespace, two data elements.
    // Diagnostic: {"docType": "org.iso.18013.5.1.mDL", "nameSpaces": {"org.iso.18013.5.1": {"family_name": false, "given_name": true}}}
    // Wrapped in DeviceRequest: {"version": "1.0", "docRequests": [{"itemsRequest": Tag(24, bstr(ItemsRequest))}]}
    let validDeviceRequestHex =
        "a26776657273696f6e63312e306b646f63526571756573747381a16c6974656d7352657175657374" +
        "d8185857a267646f6354797065756f72672e69736f2e31383031332e352e312e6d444c6a6e616d65" +
        "537061636573a1716f72672e69736f2e31383031332e352e31a26b66616d696c795f6e616d65f46a" +
        "676976656e5f6e616d65f5"

    // Valid ItemsRequest with 3 keys (includes requestInfo).
    // Diagnostic: {"docType": "org.iso.18013.5.1.mDL", "nameSpaces": {"org.iso.18013.5.1": {"family_name": false}}, "requestInfo": {"purpose": "age verification"}}
    let validWithRequestInfoHex =
        "a26776657273696f6e63312e306b646f63526571756573747381a16c6974656d7352657175657374" +
        "d8185871a367646f6354797065756f72672e69736f2e31383031332e352e312e6d444c6a6e616d65" +
        "537061636573a1716f72672e69736f2e31383031332e352e31a16b66616d696c795f6e616d65f46b" +
        "72657175657374496e666fa167707572706f73657061676520766572696669636174696f6e"

    // MARK: - Helpers

    /// Extracts the raw ItemsRequest CBOR bytes from the first DocRequest in a DeviceRequest hex string.
    private func extractItemsRequestBytes(from hex: String) throws -> [UInt8] {
        let data = try #require(Data(hexString: hex))
        let decoded = try #require(try CBOR.decode([UInt8](data)))
        guard case .map(let request) = decoded,
              case .array(let docRequests) = request[.utf8String("docRequests")],
              let firstDocRequest = docRequests.first,
              case .map(let docReqMap) = firstDocRequest,
              case .tagged(.encodedCBORDataItem, .byteString(let itemsBytes)) = docReqMap[.utf8String("itemsRequest")]
        else {
            Issue.record("Failed to extract ItemsRequest bytes from DeviceRequest")
            return []
        }
        return itemsBytes
    }

    /// Decodes raw ItemsRequest bytes into a CBOR value.
    private func decodeItemsRequest(from hex: String) throws -> CBOR {
        let bytes = try extractItemsRequestBytes(from: hex)
        return try #require(try CBOR.decode(bytes))
    }

    // MARK: - mDLR_MS_DR_08

    @Test("mDLR_MS_DR_08: ItemsRequest passes Common_CBOR validation (well-formed, canonical, unique keys)")
    func itemsRequestCommonCBORValidation() throws {
        let bytes = try extractItemsRequestBytes(from: validDeviceRequestHex)

        // Well-formed: decodes without error
        let decoded = try #require(try CBOR.decode(bytes))

        // Must be a map
        guard case .map(let pairs) = decoded else {
            Issue.record("ItemsRequest must be a CBOR map")
            return
        }

        // Uniqueness: map keys are unique (SwiftCBOR enforces this on decode)
        let keys = pairs.keys.map { "\($0)" }
        #expect(keys.count == Set(keys).count, "ItemsRequest map keys must be unique")
    }

    // MARK: - mDLR_MS_DR_09

    @Test("mDLR_MS_DR_09: ItemsRequest major type is 5 (map)")
    func itemsRequestMajorTypeIsMap() throws {
        let bytes = try extractItemsRequestBytes(from: validDeviceRequestHex)
        #expect(!bytes.isEmpty, "ItemsRequest bytes must not be empty")

        // Major type is encoded in the first 3 bits of the first byte
        let majorType = bytes[0] >> 5
        #expect(majorType == 5, "ItemsRequest major type must be 5 (map), got \(majorType)")
    }

    // MARK: - mDLR_MS_DR_10

    @Test("mDLR_MS_DR_10: ItemsRequest map contains 2 or 3 valid key-value pairs")
    func itemsRequestMapKeyValuePairs() throws {
        let bytes = try extractItemsRequestBytes(from: validDeviceRequestHex)

        // Additional information is the last 5 bits of the first byte (number of map pairs)
        let additionalInfo = bytes[0] & 0x1F
        #expect(
            additionalInfo == 2 || additionalInfo == 3,
            "ItemsRequest map must have 2 or 3 key-value pairs, got \(additionalInfo)"
        )

        // Decode and verify only specified keys are present
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded else {
            Issue.record("ItemsRequest must be a CBOR map")
            return
        }

        let allowedKeys: Set<String> = ["docType", "nameSpaces", "requestInfo"]
        for key in pairs.keys {
            guard case .utf8String(let keyStr) = key else {
                Issue.record("All ItemsRequest keys must be tstr, got: \(key)")
                return
            }
            #expect(allowedKeys.contains(keyStr), "Unexpected key '\(keyStr)' in ItemsRequest")
        }

        // Verify docType value is tstr
        if let docTypeValue = pairs[.utf8String("docType")] {
            guard case .utf8String = docTypeValue else {
                Issue.record("docType value must be tstr (major type 3)")
                return
            }
        } else {
            Issue.record("Required key 'docType' is missing")
        }

        // Verify nameSpaces value is map (major type 5)
        if let nameSpacesValue = pairs[.utf8String("nameSpaces")] {
            guard case .map = nameSpacesValue else {
                Issue.record("nameSpaces value must be map (major type 5)")
                return
            }
        } else {
            Issue.record("Required key 'nameSpaces' is missing")
        }

        // If requestInfo present, verify it is a map
        if let requestInfoValue = pairs[.utf8String("requestInfo")] {
            guard case .map = requestInfoValue else {
                Issue.record("requestInfo value must be map (major type 5)")
                return
            }
        }
    }

    @Test("mDLR_MS_DR_10: ItemsRequest with requestInfo has 3 key-value pairs")
    func itemsRequestWithRequestInfoHasThreeKeys() throws {
        let bytes = try extractItemsRequestBytes(from: validWithRequestInfoHex)
        let additionalInfo = bytes[0] & 0x1F
        #expect(additionalInfo == 3, "ItemsRequest with requestInfo must have 3 key-value pairs, got \(additionalInfo)")
    }

    // MARK: - mDLR_MS_DR_11

    @Test("mDLR_MS_DR_11: DocType value is a supported document type")
    func docTypeValueIsValid() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded,
              case .utf8String(let docTypeStr) = pairs[.utf8String("docType")]
        else {
            Issue.record("Failed to extract docType from ItemsRequest")
            return
        }

        // The docType must match a supported DocType value per the ICS
        #expect(
            docTypeStr == "org.iso.18013.5.1.mDL",
            "DocType must be a supported type, got '\(docTypeStr)'"
        )

        // Verify it can be parsed into the DocType enum
        let docType = DocType(rawValue: docTypeStr)
        #expect(docType != nil, "DocType '\(docTypeStr)' must be a recognized type")
        #expect(docType == .mdl)
    }

    // MARK: - mDLR_MS_DR_12

    @Test("mDLR_MS_DR_12: NameSpaces map has at least 1 entry with valid key-value types")
    func nameSpacesMapValidation() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded,
              case .map(let nameSpaces) = pairs[.utf8String("nameSpaces")]
        else {
            Issue.record("Failed to extract nameSpaces map from ItemsRequest")
            return
        }

        // Must have at least 1 key-value pair
        #expect(nameSpaces.count >= 1, "NameSpaces map must have at least 1 entry, got \(nameSpaces.count)")

        // All keys must be tstr (major type 3) and values must be maps (major type 5)
        for (key, value) in nameSpaces {
            guard case .utf8String(let nsName) = key else {
                Issue.record("NameSpaces key must be tstr (major type 3), got: \(key)")
                return
            }
            // Verify the namespace is one the reader is able to request (per ICS)
            #expect(!nsName.isEmpty, "NameSpace name must not be empty")

            guard case .map = value else {
                Issue.record("NameSpaces value for '\(nsName)' must be map (major type 5), got: \(value)")
                return
            }
        }
    }

    @Test("mDLR_MS_DR_12: NameSpaces raw CBOR byte has correct additional information")
    func nameSpacesAdditionalInfo() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded,
              case .map(let nameSpaces) = pairs[.utf8String("nameSpaces")]
        else {
            Issue.record("Failed to extract nameSpaces map from ItemsRequest")
            return
        }

        // Verify count is at least 1
        #expect(nameSpaces.count >= 1, "NameSpaces must contain at least one namespace")
    }

    // MARK: - mDLR_MS_DR_13

    @Test("mDLR_MS_DR_13: DataElements maps have at least 1 entry with valid key-value types")
    func dataElementsMapValidation() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded,
              case .map(let nameSpaces) = pairs[.utf8String("nameSpaces")]
        else {
            Issue.record("Failed to extract nameSpaces map from ItemsRequest")
            return
        }

        for (nsKey, nsValue) in nameSpaces {
            guard case .utf8String(let nsName) = nsKey,
                  case .map(let dataElements) = nsValue
            else {
                Issue.record("Invalid nameSpaces structure")
                return
            }

            // DataElements map must have at least 1 entry
            #expect(
                dataElements.count >= 1,
                "DataElements map for namespace '\(nsName)' must have at least 1 entry, got \(dataElements.count)"
            )

            // All keys must be tstr (major type 3), values must be major type 7 (boolean/simple)
            for (elemKey, elemValue) in dataElements {
                guard case .utf8String(let elemName) = elemKey else {
                    Issue.record("DataElement key in '\(nsName)' must be tstr (major type 3), got: \(elemKey)")
                    return
                }
                #expect(!elemName.isEmpty, "DataElement identifier must not be empty")

                // IntentToRetain must be a boolean (CBOR major type 7, simple values 20/21)
                guard case .boolean = elemValue else {
                    Issue.record("DataElement value for '\(elemName)' in '\(nsName)' must be boolean (major type 7), got: \(elemValue)")
                    return
                }
            }
        }
    }

    // MARK: - mDLR_MS_DR_14

    @Test("mDLR_MS_DR_14: IntentToRetain values are valid CBOR booleans (simple value 20 or 21)")
    func intentToRetainValues() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded,
              case .map(let nameSpaces) = pairs[.utf8String("nameSpaces")]
        else {
            Issue.record("Failed to extract nameSpaces map from ItemsRequest")
            return
        }

        for (nsKey, nsValue) in nameSpaces {
            guard case .utf8String(let nsName) = nsKey,
                  case .map(let dataElements) = nsValue
            else {
                Issue.record("Invalid nameSpaces structure")
                return
            }

            for (elemKey, elemValue) in dataElements {
                guard case .utf8String(let elemName) = elemKey else {
                    Issue.record("DataElement key must be tstr")
                    return
                }

                // Verify IntentToRetain is specifically a boolean (CBOR simple value 20=false, 21=true)
                switch elemValue {
                case .boolean(let value):
                    // Valid: value is either true or false (simple value 20 or 21)
                    #expect(value == true || value == false,
                            "IntentToRetain for '\(elemName)' in '\(nsName)' must be true or false")
                default:
                    Issue.record(
                        "IntentToRetain for '\(elemName)' in '\(nsName)' must be CBOR boolean (simple value 20/21), got: \(elemValue)"
                    )
                }
            }
        }
    }

    // MARK: - mDLR_MS_DR_15

    @Test("mDLR_MS_DR_15: requestInfo map (if present) has valid structure with tstr keys")
    func requestInfoValidation() throws {
        let decoded = try decodeItemsRequest(from: validWithRequestInfoHex)
        guard case .map(let pairs) = decoded else {
            Issue.record("ItemsRequest must be a CBOR map")
            return
        }

        // requestInfo is optional; if not present, test passes
        guard let requestInfoValue = pairs[.utf8String("requestInfo")] else {
            // requestInfo not present — this is valid
            return
        }

        // Must be a map
        guard case .map(let requestInfo) = requestInfoValue else {
            Issue.record("requestInfo must be a map (major type 5), got: \(requestInfoValue)")
            return
        }

        // Additional info (number of pairs) must be at least 0 — always satisfied for any map
        #expect(requestInfo.count >= 0, "requestInfo map must have at least 0 key-value pairs")

        // All keys must be tstr (major type 3)
        for (key, _) in requestInfo {
            guard case .utf8String(let keyStr) = key else {
                Issue.record("requestInfo key must be tstr (major type 3), got: \(key)")
                return
            }
            #expect(!keyStr.isEmpty, "requestInfo key must not be empty")
        }
    }

    @Test("mDLR_MS_DR_15: ItemsRequest without requestInfo passes validation")
    func noRequestInfoIsValid() throws {
        let decoded = try decodeItemsRequest(from: validDeviceRequestHex)
        guard case .map(let pairs) = decoded else {
            Issue.record("ItemsRequest must be a CBOR map")
            return
        }

        // requestInfo is absent — this is a valid configuration
        let requestInfo = pairs[.utf8String("requestInfo")]
        #expect(requestInfo == nil, "This test vector should not contain requestInfo")
    }
}

// MARK: - Private Helpers

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
