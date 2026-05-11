import Foundation
import SharingCryptoService
@testable import SharingOrchestration

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?
    
    func requestAndValidateCredential(for deviceRequest: DeviceRequest, in session: CredentialSessionProtocol) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
