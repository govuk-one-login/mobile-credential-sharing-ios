import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("DeviceResponse Tests")
// swiftlint:disable:next type_body_length
struct DeviceResponseTests {
    private func buildDeviceResponseCBOR(
        version: String = "1.0",
        status: UInt64 = 0,
        documents: CBOR? = nil,
        extraFields: [CBOR: CBOR] = [:]
    ) -> Data {
        var map: [CBOR: CBOR] = [
            .utf8String("version"): .utf8String(version),
            .utf8String("status"): .unsignedInt(status)
        ]
        if let documents {
            map[.utf8String("documents")] = documents
        }
        for (key, value) in extraFields {
            map[key] = value
        }
        return Data(CBOR.map(map).encode())
    }

    private func buildValidDocumentCBOR(
        docType: String = "org.iso.18013.5.1.mDL",
        nameSpace: String = "org.iso.18013.5.1",
        items: [CBOR]? = nil
    ) -> CBOR {
        let issuerSignedItems: [CBOR]
        if let items {
            issuerSignedItems = items
        } else {
            let innerBytes = CBOR.map([
                .utf8String("digestID"): .unsignedInt(0),
                .utf8String("random"): .byteString([1, 2, 3, 4]),
                .utf8String("elementIdentifier"): .utf8String("family_name"),
                .utf8String("elementValue"): .utf8String("Smith")
            ]).encode()
            issuerSignedItems = [.tagged(.encodedCBORDataItem, .byteString(innerBytes))]
        }

        let issuerAuth: CBOR = .array([
            .byteString([]),
            .map([:]),
            .null,
            .byteString([1, 2, 3])
        ])

        let issuerSigned: CBOR = .map([
            .utf8String("nameSpaces"): .map([
                .utf8String(nameSpace): .array(issuerSignedItems)
            ]),
            .utf8String("issuerAuth"): issuerAuth
        ])

        return .map([
            .utf8String("docType"): .utf8String(docType),
            .utf8String("issuerSigned"): issuerSigned
        ])
    }

    // MARK: - Encoding Tests

    @Test("DeviceResponse encodes to CBOR with documents")
    func encodesWithDocuments() throws {
        let issuerSignedItem = IssuerSignedItem(
            digestID: 0,
            random: [1, 2, 3, 4],
            elementIdentifier: "family_name",
            elementValue: .utf8String("Smith")
        )
        let issuerSigned = IssuerSigned(
            nameSpaces: ["org.iso.18013.5.1": [issuerSignedItem]],
            issuerAuth: [5, 6, 7, 8]
        )
        let document = Document(docType: .mdl, issuerSigned: issuerSigned)
        let deviceResponse = DeviceResponse(version: "1.0", documents: [document], status: .ok)

        let cbor = deviceResponse.toCBOR()

        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[.utf8String("version")] == .utf8String("1.0"))
        #expect(map[.utf8String("status")] == .unsignedInt(0))
        guard case let .array(documents) = map[.utf8String("documents")] else {
            Issue.record("Expected documents array")
            return
        }
        #expect(documents.count == 1)
    }

    @Test("DeviceResponse encodes to CBOR with documentErrors")
    func encodesWithDocumentErrors() throws {
        let documentError = DocumentError(docType: .mdl, code: .dataNotReturned, message: "Invalid request")
        let deviceResponse = DeviceResponse(version: "1.0", documents: nil, documentErrors: [documentError], status: .generalError)

        let cbor = deviceResponse.toCBOR()

        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[.utf8String("version")] == .utf8String("1.0"))
        #expect(map[.utf8String("status")] == .unsignedInt(10))
        guard case let .array(errors) = map[.utf8String("documentErrors")] else {
            Issue.record("Expected documentErrors array")
            return
        }
        #expect(errors.count == 1)
    }

    @Test("Document encodes to CBOR correctly")
    func documentEncodes() throws {
        let issuerSigned = IssuerSigned(nameSpaces: [:], issuerAuth: [1, 2, 3])
        let document = Document(docType: .mdl, issuerSigned: issuerSigned)

        let cbor = document.toCBOR()

        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[.utf8String("docType")] == .utf8String("org.iso.18013.5.1.mDL"))
    }

    @Test("IssuerSignedItem encodes as tagged CBOR data item")
    func issuerSignedItemEncodes() throws {
        let item = IssuerSignedItem(digestID: 5, random: [10, 20, 30], elementIdentifier: "birth_date", elementValue: .utf8String("1990-01-01"))

        let cbor = item.toCBOR()

        guard case let .tagged(tag, .byteString(bytes)) = cbor else {
            Issue.record("Expected tagged CBOR with byteString")
            return
        }
        #expect(tag == .encodedCBORDataItem)
        let decoded = try CBOR.decode(bytes)
        guard case let .map(map) = decoded else {
            Issue.record("Expected decoded CBOR map")
            return
        }
        #expect(map[.utf8String("digestID")] == .unsignedInt(5))
        #expect(map[.utf8String("elementIdentifier")] == .utf8String("birth_date"))
        #expect(map[.utf8String("elementValue")] == .utf8String("1990-01-01"))
    }

    @Test("DeviceSigned encodes to CBOR correctly")
    func deviceSignedEncodes() throws {
        let deviceAuth = DeviceAuth(deviceSignature: [1, 2, 3, 4, 5])
        let deviceSigned = DeviceSigned(nameSpaces: [10, 20, 30], deviceAuth: deviceAuth)

        let cbor = deviceSigned.toCBOR()

        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[.utf8String("nameSpaces")] == .tagged(.encodedCBORDataItem, .byteString([10, 20, 30])))
    }

    @Test("DocumentError encodes to CBOR correctly")
    func documentErrorEncodes() throws {
        let error = DocumentError(docType: .mdl, code: .dataNotReturned, message: "Test error")

        let cbor = error.toCBOR()

        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[.utf8String("docType")] == .utf8String("org.iso.18013.5.1.mDL"))
        #expect(map[.utf8String("errorCode")] == .unsignedInt(0))
        #expect(map[.utf8String("errorMessage")] == .utf8String("Test error"))
    }

    // MARK: - Decoding Tests

    // MARK: Reject null or empty input before CBOR decoding

    @Test("Throws invalidInput for empty data")
    func rejectsEmptyData() {
        #expect(throws: DeviceResponseError.invalidInput) {
            try DeviceResponse(data: Data())
        }
    }

    // MARK: Reject malformed CBOR or invalid Tag 24 structure

    @Test("Throws cborDecodingError for non-CBOR data")
    func rejectsNonCBORData() {
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: Data([0xFF, 0xFE, 0xFD, 0xFC, 0xFB]))
        }
    }

    @Test("Throws cborDecodingError for CBOR that is not a map")
    func rejectsCBORNonMap() {
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: Data(CBOR.array([.unsignedInt(1)]).encode()))
        }
    }

    @Test("Throws cborDecodingError when mandatory fields are missing")
    func rejectsMissingMandatoryFields() {
        // Missing version
        let noVersion = Data(CBOR.map([
            .utf8String("status"): .unsignedInt(0),
            .utf8String("documents"): .array([])
        ]).encode())
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: noVersion)
        }

        // Missing status
        let noStatus = Data(CBOR.map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("documents"): .array([])
        ]).encode())
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: noStatus)
        }
    }

    @Test("Throws cborDecodingError when Tag 24 item does not contain a byte string")
    func rejectsInvalidTag24InnerContent() {
        let invalidItem: CBOR = .tagged(.encodedCBORDataItem, .utf8String("not bytes"))
        let document = buildValidDocumentCBOR(items: [invalidItem])
        let data = buildDeviceResponseCBOR(documents: .array([document]))
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: data)
        }
    }

    // MARK: Process successful DeviceResponse with single and multiple documents

    @Test("Parses DeviceResponse with single document")
    func parsesSingleDocument() throws {
        let document = buildValidDocumentCBOR()
        let data = buildDeviceResponseCBOR(documents: .array([document]))

        let response = try DeviceResponse(data: data)

        #expect(response.version == "1.0")
        #expect(response.status == .ok)
        #expect(response.documents?.count == 1)
        #expect(response.documents?.first?.docType == .mdl)
    }

    @Test("Parses and iterates DeviceResponse with multiple documents")
    func parsesMultipleDocuments() throws {
        let documents = (0..<3).map { _ in buildValidDocumentCBOR() }
        let data = buildDeviceResponseCBOR(documents: .array(documents))

        let response = try DeviceResponse(data: data)

        #expect(response.version == "1.0")
        #expect(response.status == .ok)
        #expect(response.documents?.count == 3)
        for document in response.documents ?? [] {
            #expect(document.docType == .mdl)
            #expect(!document.issuerSigned.nameSpaces.isEmpty)
        }
    }

    // MARK: Handle DeviceRequest processing error (status 10, 11, 12)

    @Test("Throws deviceRequestProcessingError for error statuses", arguments: [
        UInt64(10), UInt64(11), UInt64(12)
    ])
    func throwsOnErrorStatus(status: UInt64) {
        let data = buildDeviceResponseCBOR(status: status)
        #expect(throws: DeviceResponseError.deviceRequestProcessingError(status: status)) {
            try DeviceResponse(data: data)
        }
    }

    // MARK: Handle Document Not Returned error (status 0, no documents)

    @Test("Throws documentNotReturned when documents array is empty or missing")
    func throwsOnNoDocuments() {
        let emptyArray = buildDeviceResponseCBOR(status: 0, documents: .array([]))
        #expect(throws: DeviceResponseError.documentNotReturned) {
            try DeviceResponse(data: emptyArray)
        }

        let missingKey = buildDeviceResponseCBOR(status: 0, documents: nil)
        #expect(throws: DeviceResponseError.documentNotReturned) {
            try DeviceResponse(data: missingKey)
        }
    }

    // MARK: Halt on partially malformed documents array

    @Test("Throws cborDecodingError when a document in the array is malformed")
    func throwsOnMalformedDocument() {
        let validDocument = buildValidDocumentCBOR()
        let malformedDocument: CBOR = .map([
            .utf8String("docType"): .utf8String("org.iso.18013.5.1.mDL")
            // missing "issuerSigned"
        ])
        let data = buildDeviceResponseCBOR(documents: .array([validDocument, malformedDocument]))
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: data)
        }
    }

    @Test("Throws cborDecodingError when document has invalid docType or is not a map")
    func throwsOnInvalidDocumentStructure() {
        // Not a map
        let notAMap = buildDeviceResponseCBOR(documents: .array([.utf8String("not a document")]))
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: notAMap)
        }

        // Unsupported docType
        let invalidDoc = buildValidDocumentCBOR(docType: "unsupported.doc.type")
        let data = buildDeviceResponseCBOR(documents: .array([invalidDoc]))
        #expect(throws: DeviceResponseError.cborDecodingError) {
            try DeviceResponse(data: data)
        }
    }

    // MARK: Extract and preserve IssuerSignedItems tagged with Tag 24

    @Test("Preserves Tag 24 items without decoding inner structure")
    func preservesTag24Items() throws {
        let taggedItems = [
            CBOR.tagged(.encodedCBORDataItem, .byteString([0xA0])),
            CBOR.tagged(.encodedCBORDataItem, .byteString([0xA1, 0x01, 0x02]))
        ]
        let document = buildValidDocumentCBOR(items: taggedItems)
        let data = buildDeviceResponseCBOR(documents: .array([document]))

        let response = try DeviceResponse(data: data)

        let parsedItems = try #require(response.documents?.first?.issuerSigned.nameSpaces["org.iso.18013.5.1"])
        #expect(parsedItems.count == 2)
        #expect(parsedItems[0].toCBOR() == taggedItems[0])
        #expect(parsedItems[1].toCBOR() == taggedItems[1])
    }

    @Test("Ignores unsupported fields without throwing")
    func ignoresUnsupportedFields() throws {
        let document = buildValidDocumentCBOR()
        let data = buildDeviceResponseCBOR(
            documents: .array([document]),
            extraFields: [
                .utf8String("documentErrors"): .array([]),
                .utf8String("zkDocuments"): .array([.utf8String("zkData")]),
                .utf8String("unknownField"): .utf8String("ignored")
            ]
        )

        let response = try DeviceResponse(data: data)

        #expect(response.version == "1.0")
        #expect(response.status == .ok)
        #expect(response.documents?.count == 1)
        #expect(response.documents?.first?.deviceSigned == nil)
        #expect(response.documentErrors == nil)
    }
}
