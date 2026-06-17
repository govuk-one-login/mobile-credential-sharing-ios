@testable import SharingCryptoService

class MockCryptoVerifierSession: CryptoVerifierSessionProtocol {
    var cryptoContext: CryptoContext?
    var setEngagementShouldThrow = false
    var setSessionKeysShouldThrow = false

    func setEngagement(cryptoContext: CryptoContext) throws {
        if setEngagementShouldThrow {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        self.cryptoContext = cryptoContext
    }

    func setSessionKeys(skReaderKey: [UInt8], skDeviceKey: [UInt8]) throws {
        if setSessionKeysShouldThrow {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        self.cryptoContext?.skReaderKey = skReaderKey
        self.cryptoContext?.skDeviceKey = skDeviceKey
    }
}
