import Foundation
import SharingCryptoService
@testable import SharingOrchestration

/// Mock error conforming to `LocalAuthCancelled` for orchestrator tests.
enum MockLocalAuthCancelledError: LocalAuthCancelled {
    case cancelled
}

/// Mock error conforming to `SignError` for orchestrator tests.
enum MockSignFailedError: SignError {
    case failed
}

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?
    var signErrorToThrow: Error?
    var filterErrorToThrow: Error?
    var stubbedSignatureBytes: Data = Data([0x01, 0x02])
    var didCallSignSigStructure = false
    var didCallFilterIssuerSigned = false
    
    func requestAndValidateCredential(for deviceRequest: DeviceRequest, in session: CredentialSessionProtocol) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func signSigStructure(in session: CryptoHolderSessionProtocol & CredentialSessionProtocol) async throws {
        didCallSignSigStructure = true
        if let signErrorToThrow { throw signErrorToThrow }
        if let errorToThrow { throw errorToThrow }
        try session.setSignatureBytes(stubbedSignatureBytes)
    }
    
    func filterIssuerSigned(for deviceRequest: SharingCryptoService.DeviceRequest, in session: any SharingOrchestration.CredentialSessionProtocol) throws {
        didCallFilterIssuerSigned = true
        if let filterErrorToThrow {
            throw filterErrorToThrow
        }
    }
}
