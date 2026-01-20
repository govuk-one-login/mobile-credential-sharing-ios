import Foundation

struct EncryptedByDevice: EncryptionParameters {
    var sharedInfo = Data("SKDevice".utf8)
    
    private let rawIdentifier: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    ]
    var identifier: Data { Data(rawIdentifier) }
    
}

extension EncryptionParameters where Self == EncryptedByDevice {
    static var device: Self { EncryptedByDevice() }
}
