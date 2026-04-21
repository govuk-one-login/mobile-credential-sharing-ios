import SharingCryptoService
import UIKit

class MockCryptoSession: CryptoSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter: Int = 1
    var skDeviceMessageCounter: Int = 1
    private(set) var sessionTranscript: SessionTranscript?
    private(set) var docType: DocType?
    
    var didSetSessionTranscriptAndDocType = false
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        self.cryptoContext = cryptoContext
    }
    
    func setSKDeviceKey(_ key: [UInt8]) throws {
        self.cryptoContext?.skDeviceKey = key
    }
    
    func setSessionTranscriptAndDocType(
        sessionTranscript: SessionTranscript,
        docType: DocType
    ) throws {
        self.sessionTranscript = sessionTranscript
        self.docType = docType
        
        didSetSessionTranscriptAndDocType = true
    }
}
