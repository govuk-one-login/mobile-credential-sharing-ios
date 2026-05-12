import Foundation
import SharingCryptoService
@testable import SharingOrchestration

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?
    var stubbedCredential: Credential = Credential(id: "mock-id", rawCredential: Data())
    var stubbedSignatureBytes: Data = Data([0x01, 0x02])
    var didCallSign = false
    var receivedSignPayload: Data?
    var receivedDocumentID: String?
    
    func requestAndValidateCredential(for deviceRequest: DeviceRequest, in session: CredentialSessionProtocol) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func sign(payload: Data, documentID: String) async throws -> Data {
        didCallSign = true
        receivedSignPayload = payload
        receivedDocumentID = documentID
        
        if let errorToThrow { throw errorToThrow }
        
        return stubbedSignatureBytes
    }
}
