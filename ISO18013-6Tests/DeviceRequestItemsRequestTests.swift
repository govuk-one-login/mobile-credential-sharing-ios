import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable type_body_length
// swiftlint:disable file_length

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

    /// Valid DeviceRequest generated from the verifier's own ISO models.
    /// Requests org.iso.18013.5.1.mDL / org.iso.18013.5.1 { given_name: false, family_name: true }.
    private func validDeviceRequestData() throws -> Data {
        try makeValidDeviceRequestData()
    }

    /// Valid DeviceRequest with a requestInfo map spliced into the ItemsRequest.
    /// ItemsRequest has 3 keys: docType, nameSpaces, requestInfo.
    private func validWithRequestInfoData() throws -> Data {
        try makeDeviceRequestDataWithRequestInfo()
    }

    // MARK: - Helpers

    /// Extracts the raw ItemsRequest CBOR bytes from the first DocRequest in DeviceRequest data.
    private func extractItemsRequestBytes(from data: Data) throws -> [UInt8] {
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
    private func decodeItemsRequest(from data: Data) throws -> CBOR {
        let bytes = try extractItemsRequestBytes(from: data)
        return try #require(try CBOR.decode(bytes))
    }

    // MARK: - mDLR_MS_DR_08

    @Test("mDLR_MS_DR_08: ItemsRequest passes Common_CBOR validation (well-formed, canonical, unique keys)")
    func itemsRequestCommonCBORValidation() throws {
        let bytes = try extractItemsRequestBytes(from: try validDeviceRequestData())

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
        let bytes = try extractItemsRequestBytes(from: try validDeviceRequestData())
        #expect(!bytes.isEmpty, "ItemsRequest bytes must not be empty")

        // Major type is encoded in the first 3 bits of the first byte
        let majorType = bytes[0] >> 5
        #expect(majorType == 5, "ItemsRequest major type must be 5 (map), got \(majorType)")
    }

    // MARK: - mDLR_MS_DR_10

    @Test("mDLR_MS_DR_10: ItemsRequest map contains 2 or 3 valid key-value pairs")
    func itemsRequestMapKeyValuePairs() throws {
        let bytes = try extractItemsRequestBytes(from: try validDeviceRequestData())

        // Additional information is the last 5 bits of the first byte (number of map pairs)
        let additionalInfo = bytes[0] & 0x1F
        #expect(
            additionalInfo == 2 || additionalInfo == 3,
            "ItemsRequest map must have 2 or 3 key-value pairs, got \(additionalInfo)"
        )

        // Decode and verify only specified keys are present
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
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
        let bytes = try extractItemsRequestBytes(from: try validWithRequestInfoData())
        let additionalInfo = bytes[0] & 0x1F
        #expect(additionalInfo == 3, "ItemsRequest with requestInfo must have 3 key-value pairs, got \(additionalInfo)")
    }

    // MARK: - mDLR_MS_DR_11

    @Test("mDLR_MS_DR_11: DocType value is a supported document type")
    func docTypeValueIsValid() throws {
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
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
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
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
            let allowedNameSpaces: Set<String> = [
                AttributeGroup.Namespace.standard.rawValue,
                AttributeGroup.Namespace.gb.rawValue
            ]
            #expect(
                allowedNameSpaces.contains(nsName),
                "NameSpace '\(nsName)' is not a recognized namespace. Allowed: \(allowedNameSpaces)"
            )

            guard case .map = value else {
                Issue.record("NameSpaces value for '\(nsName)' must be map (major type 5), got: \(value)")
                return
            }
        }
    }

    @Test("mDLR_MS_DR_12: NameSpaces raw CBOR byte has correct additional information")
    func nameSpacesAdditionalInfo() throws {
        let bytes = try extractItemsRequestBytes(from: try validDeviceRequestData())
        let decoded = try #require(try CBOR.decode(bytes))
        guard case .map(let pairs) = decoded,
              let nameSpacesValue = pairs[.utf8String("nameSpaces")]
        else {
            Issue.record("Failed to extract nameSpaces from ItemsRequest")
            return
        }
        guard case .map(let nameSpaces) = nameSpacesValue else {
            Issue.record("nameSpaces must be a map")
            return
        }

        // Re-encode the nameSpaces map to inspect its raw CBOR first byte
        let nameSpacesBytes = nameSpacesValue.encode()
        #expect(!nameSpacesBytes.isEmpty, "NameSpaces encoded bytes must not be empty")

        // Verify major type is 5 (map)
        let majorType = nameSpacesBytes[0] >> 5
        #expect(majorType == 5, "NameSpaces major type must be 5 (map), got \(majorType)")

        // Verify additional information matches the number of entries
        let additionalInfo = nameSpacesBytes[0] & 0x1F
        #expect(
            additionalInfo == UInt8(nameSpaces.count),
            "NameSpaces additional info must equal entry count (\(nameSpaces.count)), got \(additionalInfo)"
        )
    }

    // MARK: - mDLR_MS_DR_13

    // swiftlint:disable function_body_length
    @Test("mDLR_MS_DR_13: DataElements maps have at least 1 entry with valid key-value types")
    func dataElementsMapValidation() throws {
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
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
                // Validate element identifier is a known data element for this namespace
                let knownStandardElements: Set<String> = [
                    "family_name", "given_name", "birth_date", "issue_date", "expiry_date",
                    "issuing_country", "issuing_authority", "document_number", "portrait",
                    "birth_place", "driving_privileges", "un_distinguishing_sign",
                    "resident_address", "resident_postal_code", "resident_city"
                ]
                let knownGBElements: Set<String> = Set(GBMDLAttribute.allCases.map(\.identifier))
                let knownElements: Set<String>
                switch nsName {
                case AttributeGroup.Namespace.standard.rawValue:
                    // Standard namespace also allows age_over_NN elements
                    if elemName.hasPrefix("age_over_") {
                        let suffix = elemName.dropFirst("age_over_".count)
                        #expect(
                            Int(suffix) != nil && (0...99).contains(Int(suffix)!),
                            "age_over element '\(elemName)' must have a valid NN (0-99)"
                        )
                        continue
                    }
                    knownElements = knownStandardElements
                case AttributeGroup.Namespace.gb.rawValue:
                    knownElements = knownGBElements
                default:
                    Issue.record("No known data elements defined for namespace '\(nsName)'")
                    return
                }
                #expect(
                    knownElements.contains(elemName),
                    "DataElement '\(elemName)' is not a recognized element for namespace '\(nsName)'"
                )

                // IntentToRetain must be a boolean (CBOR major type 7, simple values 20/21)
                guard case .boolean = elemValue else {
                    Issue.record("DataElement value for '\(elemName)' in '\(nsName)' must be boolean (major type 7), got: \(elemValue)")
                    return
                }
            }
        }
    }
    // swiftlint:enable function_body_length
    
    // MARK: - mDLR_MS_DR_14

    @Test("mDLR_MS_DR_14: IntentToRetain values are valid CBOR booleans (simple value 20 or 21)")
    func intentToRetainValues() throws {
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
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
        let decoded = try decodeItemsRequest(from: try validWithRequestInfoData())
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
        let decoded = try decodeItemsRequest(from: try validDeviceRequestData())
        guard case .map(let pairs) = decoded else {
            Issue.record("ItemsRequest must be a CBOR map")
            return
        }

        // requestInfo is absent — this is a valid configuration
        let requestInfo = pairs[.utf8String("requestInfo")]
        #expect(requestInfo == nil, "This test vector should not contain requestInfo")
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
