import SharingCryptoService
import UIKit

class MockCryptoSession: CryptoSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter: Int = 1
    var skDeviceMessageCounter: Int = 1
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        
    }
    
    func setSKDeviceKey(_ key: [UInt8]) throws {
        self.cryptoContext?.skDeviceKey = key
    }
}
