import CredentialSharingUI
import CryptoKit
import Foundation

class MockCredentialProvider: CredentialProvider {
    private let activeCredential: MockCredential?
    private let signingStrategy: SigningStrategy
    private var signCallCount = 0

    init(activeCredential: MockCredential? = nil, signingStrategy: SigningStrategy = .success) {
        self.activeCredential = activeCredential
        self.signingStrategy = signingStrategy
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
        guard activeCredential.id == documentID else {
            throw MockCredentialProviderError.passedDocumentIdDoesNotMatchActiveCredentialId
        }

        signCallCount += 1

        switch signingStrategy {
        case .success:
            return try signWithPrivateKey(payload: payload)
        case .alwaysFail:
            throw MockSigningError.signingFailed
        case .failOnceThenSucceed:
            if signCallCount == 1 {
                throw MockSigningError.localAuthenticationCancelled
            }
            return try signWithPrivateKey(payload: payload)
        }
    }

    private func signWithPrivateKey(payload: Data) throws -> Data {
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
    case passedDocumentIdDoesNotMatchActiveCredentialId
}
