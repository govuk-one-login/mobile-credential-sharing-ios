import CryptoService
import UIKit

class MockCryptoSession: CryptoSessionProtocol {
    var cryptoContext: CryptoContext?
    
    var qrCode: UIImage?
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        
    }
}
