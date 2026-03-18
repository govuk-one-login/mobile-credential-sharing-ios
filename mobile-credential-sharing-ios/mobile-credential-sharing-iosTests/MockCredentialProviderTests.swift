import CredentialSharingUI
import Foundation
import Testing

@testable import mobile_credential_sharing_ios

@Suite("MockCredentialProvider Tests")
struct MockCredentialProviderTests {
    
    @Test("Returns mock credential for any request")
    func returnsMockCredential() async throws {
        let provider = MockCredentialProvider()
        let request = CredentialRequest(documentTypes: ["org.iso.18013.5.1.mDL"])
        
        let credentials = try await provider.getCredentials(for: request)
        
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "mock-credential-id")
    }
    
    @Test("Returns credential with empty CBOR data")
    func returnsEmptyCBORData() async throws {
        let provider = MockCredentialProvider()
        let request = CredentialRequest(documentTypes: ["test"])
        
        let credentials = try await provider.getCredentials(for: request)
        
        #expect(credentials.first?.rawCredential.isEmpty == true)
    }
    
    @Test("Handles multiple document types in request")
    func handlesMultipleDocumentTypes() async throws {
        let provider = MockCredentialProvider()
        let request = CredentialRequest(documentTypes: ["type1", "type2", "type3"])
        
        let credentials = try await provider.getCredentials(for: request)
        
        #expect(credentials.count == 1)
    }
    
    @Test("Returns mock signature for any payload")
    func returnsMockSignature() async throws {
        let provider = MockCredentialProvider()
        let payload = Data([0x01, 0x02, 0x03])
        
        let signature = try await provider.sign(payload: payload, documentID: "test-doc")
        
        #expect(signature.isEmpty == true)
    }
    
    @Test("Signs with different document IDs")
    func signsWithDifferentDocumentIds() async throws {
        let provider = MockCredentialProvider()
        let payload = Data([0xFF])
        
        let signature1 = try await provider.sign(payload: payload, documentID: "doc-1")
        let signature2 = try await provider.sign(payload: payload, documentID: "doc-2")
        
        #expect(signature1.isEmpty == true)
        #expect(signature2.isEmpty == true)
    }
    
    @Test("Signs empty payload")
    func signsEmptyPayload() async throws {
        let provider = MockCredentialProvider()
        let emptyPayload = Data()
        
        let signature = try await provider.sign(payload: emptyPayload, documentID: "test")
        
        #expect(signature.isEmpty == true)
    }
    
    @Test("Signs large payload")
    func signsLargePayload() async throws {
        let provider = MockCredentialProvider()
        let largePayload = Data(repeating: 0xFF, count: 1024)
        
        let signature = try await provider.sign(payload: largePayload, documentID: "large-doc")
        
        #expect(signature.isEmpty == true)
    }
}
