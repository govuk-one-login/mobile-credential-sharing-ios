import Foundation

struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
}

struct EDeviceKey: Codable {
    // Setting value as String for now
    let key: String
}
