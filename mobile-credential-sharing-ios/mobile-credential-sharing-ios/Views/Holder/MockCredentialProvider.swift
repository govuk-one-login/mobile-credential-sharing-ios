import CredentialSharingUI
import CryptoKit
import Foundation
import SharingLogging

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

    func sign(payload: Data, documentID: String) async throws(CredentialSigningError) -> Data {
        guard let activeCredential else {
            Logger.log("MockCredentialProvider: no active credential", level: .error)
            throw .unrecoverable
        }
        guard activeCredential.id == documentID else {
            Logger.log("MockCredentialProvider: documentID mismatch", level: .error)
            throw .unrecoverable
        }

        signCallCount += 1

        switch signingStrategy {
        case .success:
            return try signWithPrivateKey(payload: payload)
        case .alwaysFail:
            throw .unrecoverable
        case .failOnceThenSucceed:
            if signCallCount == 1 {
                throw .recoverable
            }
            return try signWithPrivateKey(payload: payload)
        }
    }

    private func signWithPrivateKey(payload: Data) throws(CredentialSigningError) -> Data {
        guard let activeCredential else {
            throw .unrecoverable
        }
        do {
            let privateKey = try P256.Signing.PrivateKey(rawRepresentation: activeCredential.privateKey)
            let signature = try privateKey.signature(for: payload)
            return signature.rawRepresentation
        } catch {
            throw .unrecoverable
        }
    }
}
