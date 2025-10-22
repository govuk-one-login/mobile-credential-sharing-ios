import Foundation

struct DeviceEngagement {
    let version: String = "1.0"
    let secuirty: Security
}

struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
}

struct CipherSuite {
    let identifier: UInt8
}

extension CipherSuite {
    public static let iso18013 = CipherSuite(identifier: 1)
}

struct EDeviceKey: Codable {
    // Setting value as String for now
    let key: String
}
