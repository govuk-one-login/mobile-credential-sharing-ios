import Foundation

extension MockCredential {
    /// Jane Doe credential whose `CredentialProvider.sign()` always throws a fatal signing error.
    /// Used to simulate an unrecoverable signing failure without requiring the host app.
    static func janeDoeSigningFailure(bundle: Bundle = .main) -> MockCredential {
        let base = janeDoe(bundle: bundle)
        return MockCredential(
            id: base.id,
            displayName: "Jane Doe (Signing Failure)",
            rawCredential: base.rawCredential,
            privateKey: base.privateKey,
            signingStrategy: .alwaysFail
        )
    }
}
