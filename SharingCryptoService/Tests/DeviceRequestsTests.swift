import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("DeviceRequest Tests")
struct DeviceRequestsTests {
    @Test("Successfully decodes a CBOR device request")
    func successfulCBORDecoding() throws {
        // Given
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfVvZG9jdW1lbnRfbnVtYmVy9XJkcml2aW5nX3ByaXZpbGVnZXP1amlzc3VlX2RhdGX1a2V4cGlyeV9kYXRl9Whwb3J0cmFpdPQ"
        
        // When
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        
        // Then
        #expect(deviceRequest.version == "1.0")
        #expect(deviceRequest.docRequests.count == 1)
        
        let documentRequest = try #require(deviceRequest.docRequests.first)
        #expect(documentRequest.itemsRequest.docType == .mdl)
        #expect(documentRequest.itemsRequest.nameSpaces.count == 1)
        
        let nameSpace = try #require(documentRequest.itemsRequest.nameSpaces.first)
        #expect(nameSpace.name == "org.iso.18013.5.1")
        #expect(nameSpace.elements.count == 6)

        #expect(nameSpace.elements.contains(DataElement(identifier: "family_name", intentToRetain: true)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "expiry_date", intentToRetain: true)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "document_number", intentToRetain: true)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "driving_privileges", intentToRetain: true)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "issue_date", intentToRetain: true)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "portrait", intentToRetain: false)))
        
        print("Decoded device request is: \(deviceRequest)")
    }
    
    @Test("Successfully decodes the DeviceRequest when it contains optional readerAuth field")
    func successfullyDecodesWithReaderAuth() throws {
        // Given
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GibGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfVvZG9jdW1lbnRfbnVtYmVy9XJkcml2aW5nX3ByaXZpbGVnZXP1amlzc3VlX2RhdGX1a2V4cGlyeV9kYXRl9Whwb3J0cmFpdPRqcmVhZGVyQXV0aIRDoQEmoRghWQG3MIIBszCCAVigAwIBAgIUdVJxX2rdMj1JNKG6F13JRXVdi1AwCgYIKoZIzj0EAwIwFjEUMBIGA1UEAwwLcmVhZGVyIHJvb3QwHhcNMjAxMDAxMDAwMDAwWhcNMjMxMjMxMDAwMDAwWjARMQ8wDQYDVQQDDAZyZWFkZXIwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAT4kS7g-RK2vmg7ovoBIbJjDmAbK2KN_ztE9jlOqpq9vMIUnSnW_xo-CRE1F35cPZxX87-Dl2Hu0Cxk3YKuHTu_o4GIMIGFMBwGA1UdHwQVMBMwEaAPoA2CC2V4YW1wbGUuY29tMB0GA1UdDgQWBBTy38Ssr8XzC0ZPraIL_NUzr14H9TAfBgNVHSMEGDAWgBTPt6iBuupfMrb7kcwpWQxQ36xBbjAOBgNVHQ8BAf8EBAMCB4AwFQYDVR0lAQH_BAswCQYHKIGMXQUBBjAKBggqhkjOPQQDAgNJADBGAiEA-56jtob9fqLwI0hY_4MotO_vah73HsSq5OMHIG-SFJMCIQCblPDXOd-oTMop7-1SndSDis_Ytr7iEtxjIMRv64OaNfZYQB80AAaQY8GJE4vc0vYxQnxYlCQRP8nsJs68rKz825aV0o6ZlTvsq8TjCrTvrMg5qB-RWZM9GSUn7pG0Sbt_gL8"
        
        // When
        #expect(throws: Never.self) {
            // Then
            try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        }
    }
    
    @Test("Correctly throws error when given invalid initial device request data")
    func throwsErrorInvalidDeviceRequest() throws {
        // Given
        let error = DeviceRequestError.deviceRequestWasIncorrectlyStructured
        
        // When
        let data = Data([01])
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
    }
    
    @Test("Correctly throws error when given empty docRequest data")
    func throwsErrorEmptyDocRequest() throws {
        // Given
        let error = DeviceRequestError.docRequestWasEmpty
        
        // When
        let data = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4A"))
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
        print(try #require(error.errorDescription))
    }
    
    @Test("Correctly throws error when given invalid docRequest data")
    func throwsErrorInvalidDocRequest() throws {
        // Given
        let error = DeviceRequestError.docRequestWasIncorrectlyStructured
        
        // When
        let data = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4Gg"))
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
    }
    
    @Test("Correctly throws error when given invalid itemsRequest data")
    func throwsErrorInvalidItemsRequest() throws {
        // Given
        let error = DeviceRequestError.itemsRequestWasIncorrectlyStructured
        
        // When
        let data = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYQaA"))
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
    }
    
    @Test("Correctly throws error when given invalid nameSpace data")
    func throwsErrorInvalidNameSpaceRequest() throws {
        // Given
        let error = DeviceRequestError.nameSpaceWasIncorrectlyStructured
        
        // When
        // swiftlint:disable:next line_length
        let data = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWICiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOma2ZhbWlseV9uYW1l9W9kb2N1bWVudF9udW1iZXL1cmRyaXZpbmdfcHJpdmlsZWdlc_VqaXNzdWVfZGF0ZfVrZXhwaXJ5X2RhdGX1aHBvcnRyYWl09A"))
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
    }
    
    @Test("Correctly throws error when given unsupported document type data")
    func throwsErrorUnsupportedDocumentType() throws {
        // Given
        let error = DeviceRequestError.unsupportedDocumentType
        
        // When
        // swiftlint:disable:next line_length
        let data = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWIqiZ2RvY1R5cGVsaW52YWxpZC10eXBlam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfVvZG9jdW1lbnRfbnVtYmVy9XJkcml2aW5nX3ByaXZpbGVnZXP1amlzc3VlX2RhdGX1a2V4cGlyeV9kYXRl9Whwb3J0cmFpdPQ"))
        
        // Then
        #expect(throws: error) {
            try DeviceRequest(data: data)
        }
        
        #expect(error.errorDescription == "\(error): status code 20")
    }
    
    @Test("Throws CBOR decoding error when passed invalid CBOR to decode")
    func throwsErrorWhenCannotDecodeCBOR() throws {
        let error = DeviceRequestError.dataIsNotValidCBOR
        
        #expect(throws: error) {
            try DeviceRequest(data: Data())
        }
        
        #expect(error.errorDescription == "dataIsNotValidCBOR: status code 11")
        print(try #require(error.errorDescription))
    }

    @Test("DeviceRequest contains version 1.0 and exactly one DocRequest")
    func deviceRequestModelHierarchy() throws {
        // GIVEN
        let docRequest = DocRequest(
            itemsRequest: ItemsRequest(
                docType: .mdl,
                nameSpaces: [
                    NameSpace(name: "org.iso.18013.5.1", elements: [
                        DataElement(identifier: "portrait", intentToRetain: true)
                    ])
                ]
            )
        )

        // WHEN
        let deviceRequest = DeviceRequest(docRequests: [docRequest])

        // THEN
        #expect(deviceRequest.version == "1.0")
        #expect(deviceRequest.docRequests.count == 1)
        #expect(deviceRequest.docRequests.first?.itemsRequest.docType == .mdl)
    }

    @Test("DeviceRequest encodes to raw CBOR bytes with Tag 24 preserved on itemsRequest")
    func successfulCBOREncoding() throws {
        // GIVEN
        let docRequest = DocRequest(
            itemsRequest: ItemsRequest(
                docType: .mdl,
                nameSpaces: [
                    NameSpace(name: "org.iso.18013.5.1", elements: [
                        DataElement(identifier: "given_name", intentToRetain: true),
                        DataElement(identifier: "family_name", intentToRetain: false)
                    ])
                ]
            )
        )
        let deviceRequest = DeviceRequest(docRequests: [docRequest])

        // WHEN
        let encodedBytes = deviceRequest.encode(options: CBOROptions())

        // THEN - output is raw bytes (not Tag 24 wrapped)
        let decoded = try #require(try CBOR.decode(encodedBytes))
        guard case .map(let map) = decoded else {
            Issue.record("Expected CBOR map, not a tagged value")
            return
        }

        // AND - version is correct
        #expect(map[CBOR.utf8String("version")] == .utf8String("1.0"))

        // AND - docRequests array is present with nested structure
        guard case .array(let docRequests) = map[CBOR.utf8String("docRequests")] else {
            Issue.record("Expected docRequests array")
            return
        }
        #expect(docRequests.count == 1)

        // AND - itemsRequest retains Tag 24 wrapping inside the DocRequest
        guard case .map(let docRequestMap) = docRequests.first,
              case .tagged(let tag, .byteString(_)) = docRequestMap[CBOR.utf8String("itemsRequest")] else {
            Issue.record("Expected itemsRequest to be Tag 24 wrapped")
            return
        }
        #expect(tag == .encodedCBORDataItem)
    }
    
    @Test("Encoded DeviceRequest contains exactly 2 keys: version and docRequests")
    func deviceRequestStructure() throws {
        // GIVEN
        let docRequest = DocRequest(
            itemsRequest: ItemsRequest(
                docType: .mdl,
                nameSpaces: [
                    NameSpace(name: "org.iso.18013.5.1", elements: [
                        DataElement(identifier: "age_over_21", intentToRetain: false)
                    ])
                ]
            )
        )
        let deviceRequest = DeviceRequest(docRequests: [docRequest])

        // WHEN
        let encodedBytes = deviceRequest.encode(options: CBOROptions())
        let decoded = try #require(try CBOR.decode(encodedBytes))

        // THEN - map contains exactly 2 key-value pairs
        guard case .map(let map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map.count == 2)

        // AND - only keys are "version" and "docRequests"
        let versionValue = try #require(map[CBOR.utf8String("version")])
        guard case .utf8String(let version) = versionValue else {
            Issue.record("Expected version to be a tstr")
            return
        }
        #expect(version == "1.0")

        let docRequestsValue = try #require(map[CBOR.utf8String("docRequests")])
        guard case .array(let array) = docRequestsValue else {
            Issue.record("Expected docRequests to be an array")
            return
        }
        #expect(array.count == 1)

        // AND - no additional fields
        #expect(map[CBOR.utf8String("deviceRequestInfo")] == nil)
    }

    @Test("Encode then decode produces equivalent DeviceRequest")
    func encodeDecodeDeviceRequest() throws {
        // GIVEN
        let originalDR = DeviceRequest(docRequests: [
            DocRequest(
                itemsRequest: ItemsRequest(
                    docType: .mdl,
                    nameSpaces: [
                        NameSpace(name: "org.iso.18013.5.1", elements: [
                            DataElement(identifier: "family_name", intentToRetain: true),
                            DataElement(identifier: "portrait", intentToRetain: false)
                        ]),
                        NameSpace(name: "org.iso.18013.5.1.GB", elements: [
                            DataElement(identifier: "title", intentToRetain: false)
                        ])
                    ]
                )
            )
        ])

        // WHEN
        let encoded = Data(originalDR.encode(options: CBOROptions()))
        print("DeviceRequest hex: \(encoded.map { String(format: "%02x", $0) }.joined())")
        let decoded = try DeviceRequest(data: encoded)

        // THEN
        #expect(decoded.version == originalDR.version)
        #expect(decoded.docRequests.count == originalDR.docRequests.count)
        #expect(decoded.docRequests.first?.itemsRequest.docType == .mdl)
        #expect(decoded.docRequests.first?.itemsRequest.nameSpaces.count == 2)

        let standardNS = try #require(decoded.docRequests.first?.itemsRequest.nameSpaces.first { $0.name == "org.iso.18013.5.1" })
        #expect(standardNS.elements.contains(DataElement(identifier: "family_name", intentToRetain: true)))
        #expect(standardNS.elements.contains(DataElement(identifier: "portrait", intentToRetain: false)))

        let gbNS = try #require(decoded.docRequests.first?.itemsRequest.nameSpaces.first { $0.name == "org.iso.18013.5.1.GB" })
        #expect(gbNS.elements.contains(DataElement(identifier: "title", intentToRetain: false)))
    }
}
