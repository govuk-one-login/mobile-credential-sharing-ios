import Foundation

public protocol EncryptionParameters {
    var sharedInfo: Data { get }
    var identifier: Data { get }
}
