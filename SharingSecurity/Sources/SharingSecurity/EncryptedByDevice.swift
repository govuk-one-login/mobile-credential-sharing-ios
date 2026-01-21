import Foundation

public struct EncryptedByDevice: EncryptionParameters {
    public var sharedInfo = Data("SKDevice".utf8)
    
    private let rawIdentifier: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
    ]
    public var identifier: Data { Data(rawIdentifier) }
}

extension EncryptionParameters where Self == EncryptedByDevice {
    public static var device: Self { EncryptedByDevice() }
}
