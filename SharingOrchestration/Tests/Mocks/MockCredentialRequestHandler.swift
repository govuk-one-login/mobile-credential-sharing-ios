import Foundation
import SharingCryptoService
@testable import SharingOrchestration

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?
    var stubbedSignatureBytes: Data = Data([0x01, 0x02])
    var didCallSignDeviceAuthenticationBytes = false
    
    func requestAndValidateCredential(for deviceRequest: DeviceRequest, in session: CredentialSessionProtocol) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }

    func signDeviceAuthenticationBytes(in session: CryptoSessionProtocol & CredentialSessionProtocol) async throws {
        didCallSignDeviceAuthenticationBytes = true
        if let errorToThrow { throw errorToThrow }
        try session.setSignatureBytes(stubbedSignatureBytes)
    }
    
    func filterIssuerSigned(for deviceRequest: SharingCryptoService.DeviceRequest, in session: any SharingOrchestration.CredentialSessionProtocol) throws {
        
    }
}
