import Foundation

protocol EncryptionParameters {
    var sharedInfo: Data { get }
    var identifier: Data { get }
}
