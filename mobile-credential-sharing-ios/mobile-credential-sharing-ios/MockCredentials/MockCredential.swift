import Foundation

struct MockCredential: Sendable {
    let id: String
    let displayName: String
    let rawCredential: Data
    let privateKey: Data
    let signingStrategy: SigningStrategy

    init(
        id: String,
        displayName: String,
        rawCredential: Data,
        privateKey: Data,
        signingStrategy: SigningStrategy = .success
    ) {
        self.id = id
        self.displayName = displayName
        self.rawCredential = rawCredential
        self.privateKey = privateKey
        self.signingStrategy = signingStrategy
    }
}
