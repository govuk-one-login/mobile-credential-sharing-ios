import Foundation

extension MockCredential {
    /// Jane Doe credential whose `IssuerAuth` COSE_Sign1 protected header omits the optional
    /// `x5t` thumbprint (label 34). The device key in the MSO matches the base Jane Doe
    /// credential, so signing reuses the same private key; only the issuer-signed structure differs.
    /// Used to exercise the path where the protected `x5t` is absent (it is optional per RFC 9360).
    static func janeDoeAbsentX5t(bundle: Bundle = .main) -> MockCredential {
        let base = createMock(
            for: "JaneDoeCredentialAbsentX5t",
            privateKeyHex: "7694cedd963ac024bc71adc707b38ec30297fb8091344be08d1793f4d88e0c12",
            bundle: bundle
        )
        return MockCredential(
            id: "jane-doe-absent-x5t",
            displayName: "Jane Doe (absent x5t)",
            rawCredential: base.rawCredential,
            privateKey: base.privateKey
        )
    }
}
