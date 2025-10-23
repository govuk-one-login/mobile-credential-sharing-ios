import Foundation
import SharingSecurity

struct Security {
    let cipherSuiteIdentifier: CipherSuite
    let eDeviceKey: EDeviceKey
}

typealias EDeviceKey = COSEKey
