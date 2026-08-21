import Foundation

extension MockCredential {
    /// Jane Doe credential whose `CredentialProvider.sign()` throws a local authentication cancelled
    /// error on the first call, then signs normally on subsequent calls.
    /// Used to simulate the user cancelling biometric/passcode auth once before retrying successfully.
    static func janeDoeAuthCancelledOnce(bundle: Bundle = .main) -> MockCredential {
        let base = janeDoe(bundle: bundle)
        return MockCredential(
            id: base.id,
            displayName: "Jane Doe (Authentication Cancelled Once)",
            rawCredential: base.rawCredential,
            privateKey: base.privateKey,
            signingStrategy: .failOnceThenSucceed
        )
    }
}
