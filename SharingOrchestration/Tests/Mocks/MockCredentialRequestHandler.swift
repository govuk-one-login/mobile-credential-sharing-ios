import Foundation
import SharingCryptoService
@testable import SharingOrchestration

class MockCredentialRequestHandler: CredentialRequestHandlerProtocol {
    var errorToThrow: Error?

    func requestAndValidate(for deviceRequest: DeviceRequest) async throws {
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
