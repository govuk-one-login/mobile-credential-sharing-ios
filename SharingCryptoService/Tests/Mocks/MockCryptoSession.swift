import SharingCryptoService
import UIKit

class MockCryptoSession: CryptoHolderSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter: Int = 1
    var skDeviceMessageCounter: Int = 1
    private(set) var sessionTranscript: SessionTranscript?
    private(set) var docType: DocType?
    private(set) var deviceAuthenticationBytes: Data?
    private(set) var signatureBytes: Data?
    private(set) var deviceSigned: DeviceSigned?
    
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

    func setDeviceAuthenticationBytes(_ bytes: Data) throws {
        self.deviceAuthenticationBytes = bytes
    }

    func setSignatureBytes(_ bytes: Data) throws {
        self.signatureBytes = bytes
    }

    func setDeviceSigned(deviceSigned: DeviceSigned) throws {
        self.deviceSigned = deviceSigned
    }
}
