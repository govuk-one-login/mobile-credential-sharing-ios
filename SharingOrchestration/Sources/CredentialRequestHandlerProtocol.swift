import Foundation
import SharingCryptoService
import SwiftCBOR

public enum CredentialRequestError: LocalizedError {
    case getCredentialsError
    case noCredentialsReturned
    case msoDecodingFailed
    case docTypeMismatch
}

public protocol CredentialRequestHandlerProtocol {
    func requestAndValidate(for deviceRequest: DeviceRequest) async throws -> Data
}
