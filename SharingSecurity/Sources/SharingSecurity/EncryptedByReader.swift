import Foundation

public struct EncryptedByReader: EncryptionParameters {
    public let sharedInfo = Data("SKReader".utf8)

    let rawIdentifier: [UInt8] = [
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ]
    public var identifier: Data { Data(rawIdentifier) }
}

extension EncryptionParameters where Self == EncryptedByReader {
    public static var reader: EncryptionParameters {
        EncryptedByReader()
    }
}
