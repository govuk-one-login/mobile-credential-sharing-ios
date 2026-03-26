import CredentialSharingUI
import CryptoKit
import Foundation

class MockCredentialProvider: CredentialProvider {
    private let activeCredential: MockCredential?

    init(activeCredential: MockCredential? = nil) {
        self.activeCredential = activeCredential
    }

    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        guard let activeCredential else { return [] }
        return [Credential(
            id: activeCredential.id,
            rawCredential: activeCredential.rawCredential
        )]
    }

    func sign(payload: Data, documentID: String) async throws -> Data {
        guard let activeCredential else {
            throw MockCredentialProviderError.noActiveCredential
        }
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: activeCredential.privateKey)
        let signature = try privateKey.signature(for: payload)
        return signature.rawRepresentation
    }
}

enum MockCredentialProviderError: Error {
    case noActiveCredential
}
