@testable import SharingCryptoService

class MockCryptoVerifierSession: CryptoVerifierSessionProtocol {
    var cryptoContext: CryptoContext?
    var setEngagementShouldThrow = false

    func setEngagement(cryptoContext: CryptoContext) throws {
        if setEngagementShouldThrow {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        self.cryptoContext = cryptoContext
    }
}
