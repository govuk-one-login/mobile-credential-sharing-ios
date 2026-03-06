@testable import CryptoService
import Foundation
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
        #expect(documentRequest.itemsRequest.documentType == .mdl)
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
        
        print(deviceRequest)
    }
}
