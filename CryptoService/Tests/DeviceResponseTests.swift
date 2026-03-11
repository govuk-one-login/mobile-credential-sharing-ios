@testable import CryptoService
import Foundation
import SwiftCBOR
import Testing

@Suite("DeviceResponse Tests")
struct DeviceResponseTests {
    @Test("DeviceResponse encodes to CBOR with documents")
    func encodesWithDocuments() throws {
        // Given
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
        
        let document = Document(
            docType: .mdl,
            issuerSigned: issuerSigned
        )
        
        let deviceResponse = DeviceResponse(
            version: "1.0",
            documents: [document],
            status: .ok
        )
        
        // When
        let cbor = deviceResponse.toCBOR()
        
        // Then
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
        // Given
        let documentError = DocumentError(
            docType: .mdl,
            code: .dataNotAvailable,
            message: "Invalid request"
        )
        
        let deviceResponse = DeviceResponse(
            version: "1.0",
            documents: nil,
            documentErrors: [documentError],
            status: .generalError
        )
        
        // When
        let cbor = deviceResponse.toCBOR()
        
        // Then
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
        // Given
        let issuerSigned = IssuerSigned(
            nameSpaces: [:],
            issuerAuth: [1, 2, 3]
        )
        
        let document = Document(
            docType: .mdl,
            issuerSigned: issuerSigned
        )
        
        // When
        let cbor = document.toCBOR()
        
        // Then
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        
        #expect(map[.utf8String("docType")] == .utf8String("org.iso.18013.5.1.mDL"))
    }
    
    @Test("IssuerSignedItem encodes as tagged CBOR data item")
    func issuerSignedItemEncodes() throws {
        // Given
        let item = IssuerSignedItem(
            digestID: 5,
            random: [10, 20, 30],
            elementIdentifier: "birth_date",
            elementValue: .utf8String("1990-01-01")
        )
        
        // When
        let cbor = item.toCBOR()
        
        // Then
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
        // Given
        let deviceAuth = DeviceAuth(deviceSignature: [1, 2, 3, 4, 5])
        let deviceSigned = DeviceSigned(
            nameSpaces: [10, 20, 30],
            deviceAuth: deviceAuth
        )
        
        // When
        let cbor = deviceSigned.toCBOR()
        
        // Then
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        
        #expect(map[.utf8String("nameSpaces")] == .byteString([10, 20, 30]))
    }
    
    @Test("DocumentError encodes to CBOR correctly")
    func documentErrorEncodes() throws {
        // Given
        let error = DocumentError(
            docType: .mdl,
            code: .invalidRequest,
            message: "Test error"
        )
        
        // When
        let cbor = error.toCBOR()
        
        // Then
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }
        
        #expect(map[.utf8String("docType")] == .utf8String("org.iso.18013.5.1.mDL"))
        #expect(map[.utf8String("errorCode")] == .unsignedInt(2))
        #expect(map[.utf8String("errorMessage")] == .utf8String("Test error"))
    }
}
