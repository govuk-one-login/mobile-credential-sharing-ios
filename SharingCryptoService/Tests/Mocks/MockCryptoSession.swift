import SharingCryptoService
import UIKit

class MockCryptoSession: CryptoHolderSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter: Int = 1
    var skDeviceMessageCounter: Int = 1
    private(set) var sessionTranscript: SessionTranscript?
    var docType: DocType?
    private(set) var sigStructureBytes: Data?
    private(set) var signatureBytes: Data?
    private(set) var deviceSigned: DeviceSigned?
    
    var didSetSessionTranscript = false
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {
        self.cryptoContext = cryptoContext
    }
    
    func setSKDeviceKey(_ key: [UInt8]) throws {
        self.cryptoContext?.skDeviceKey = key
    }
    
    func setSessionTranscript(
        _ sessionTranscript: SessionTranscript
    ) throws {
        self.sessionTranscript = sessionTranscript
        didSetSessionTranscript = true
    }

    func setSigStructureBytes(_ bytes: Data) throws {
        self.sigStructureBytes = bytes
    }

    func setSignatureBytes(_ bytes: Data) throws {
        self.signatureBytes = bytes
    }

    func setDeviceSigned(deviceSigned: DeviceSigned) throws {
        self.deviceSigned = deviceSigned
    }
}
