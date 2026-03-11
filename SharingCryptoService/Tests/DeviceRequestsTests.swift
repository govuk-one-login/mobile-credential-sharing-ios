import Foundation
@testable import SharingCryptoService
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
    }
}
