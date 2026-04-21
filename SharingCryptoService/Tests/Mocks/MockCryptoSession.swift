import SharingCryptoService
import UIKit

class MockCryptoSession: CryptoSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter: Int = 1
    var skDeviceMessageCounter: Int = 1
    var sessionTranscript: SessionTranscript?
    var docType: DocType?
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        self.cryptoContext = cryptoContext
    }
    
    func setSKDeviceKey(_ key: [UInt8]) throws {
        self.cryptoContext?.skDeviceKey = key
    }
}
