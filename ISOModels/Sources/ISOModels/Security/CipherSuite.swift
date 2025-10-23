import Foundation

struct CipherSuite {
    let identifier: UInt64
}

extension CipherSuite {
    public static let iso18013 = CipherSuite(identifier: 1)
}
