@testable import CredentialSharingUI
import Foundation
import Testing

@Suite("CredentialProvider Protocol Tests")
struct CredentialProviderTests {
    
    @Test("CredentialRequest initializes with document types")
    func credentialRequestInitialization() {
        let request = CredentialRequest(documentTypes: ["org.iso.18013.5.1.mDL"])
        
        #expect(request.documentTypes.count == 1)
        #expect(request.documentTypes.first == "org.iso.18013.5.1.mDL")
    }
    
    @Test("CredentialRequest handles multiple document types")
    func credentialRequestMultipleTypes() {
        let types = ["type1", "type2", "type3"]
        let request = CredentialRequest(documentTypes: types)
        
        #expect(request.documentTypes.count == 3)
        #expect(request.documentTypes == types)
    }
    
    @Test("Credential initializes with id and raw data")
    func credentialInitialization() {
        let testData = Data([0x01, 0x02, 0x03])
        let credential = Credential(id: "test-credential", rawCredential: testData)
        
        #expect(credential.id == "test-credential")
        #expect(credential.rawCredential == testData)
    }
    
    @Test("Credential handles empty data")
    func credentialEmptyData() {
        let credential = Credential(id: "empty", rawCredential: Data())
        
        #expect(credential.id == "empty")
        #expect(credential.rawCredential.isEmpty)
    }
    
    @Test("Mock provider returns credentials")
    func mockProviderReturnsCredentials() async throws {
        let provider = TestCredentialProvider()
        let request = CredentialRequest(documentTypes: ["test"])
        
        let credentials = try await provider.getCredentials(for: request)
        
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "mock-id")
    }
    
    @Test("Mock provider signs payload")
    func mockProviderSignsPayload() async throws {
        let provider = TestCredentialProvider()
        let payload = Data([0x01, 0x02, 0x03])
        
        let signature = try await provider.sign(payload: payload, documentId: "test-doc")
        
        #expect(!signature.isEmpty)
    }
}

// MARK: - Test Implementation
private class TestCredentialProvider: CredentialProvider {
    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        return [Credential(id: "mock-id", rawCredential: Data([0x01, 0x02]))]
    }
    
    func sign(payload: Data, documentId: String) async throws -> Data {
        return Data([0xFF, 0xEE])
    }
}
