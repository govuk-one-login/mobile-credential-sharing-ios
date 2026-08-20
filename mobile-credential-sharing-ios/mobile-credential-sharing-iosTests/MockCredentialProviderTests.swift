import CryptoKit
import Foundation
import SharingOrchestration
import Testing

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("MockCredentialProvider Tests")
struct MockCredentialProviderTests {
    let testCredential = MockCredential(
        id: "test-id",
        displayName: "Test User",
        rawCredential: Data([0xA1, 0x01, 0x02]),
        privateKey: P256.Signing.PrivateKey().rawRepresentation
    )

    // MARK: Provider Initialisation

    @Test("Holds reference to active credential")
    func holdsActiveCredential() async throws {
        // Given
        let provider = MockCredentialProvider(activeCredential: testCredential)

        // When
        let credentials = try await provider.getCredentials(for: CredentialRequest(documentTypes: []))

        // Then
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "test-id")
    }

    // MARK: getCredentials

    @Test("Returns active credential regardless of requested document types")
    func returnsActiveCredentialIgnoringDocumentTypes() async throws {
        // Given
        let provider = MockCredentialProvider(activeCredential: testCredential)
        let request = CredentialRequest(documentTypes: ["some.unrelated.type"])

        // When
        let credentials = try await provider.getCredentials(for: request)

        // Then
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "test-id")
        #expect(credentials.first?.rawCredential == testCredential.rawCredential)
    }

    @Test("Returns empty array when no active credential")
    func returnsEmptyWhenNoActiveCredential() async throws {
        // Given
        let provider = MockCredentialProvider()
        let request = CredentialRequest(documentTypes: ["org.iso.18013.5.1.mDL"])

        // When
        let credentials = try await provider.getCredentials(for: request)

        // Then
        #expect(credentials.isEmpty)
    }

    // MARK: sign (success strategy)

    @Test("Produces valid P256 signature")
    func producesValidSignature() async throws {
        // Given
        let provider = MockCredentialProvider(activeCredential: testCredential)
        let payload = Data("device-authentication-payload".utf8)

        // When
        let signatureData = try await provider.sign(payload: payload, documentID: "test-id")

        // Then
        let publicKey = try P256.Signing.PrivateKey(
            rawRepresentation: testCredential.privateKey
        ).publicKey
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
        #expect(publicKey.isValidSignature(signature, for: payload))
    }

    @Test("Throws when signing without active credential")
    func throwsWhenSigningWithoutActiveCredential() async {
        // Given
        let provider = MockCredentialProvider()

        // When / Then
        await #expect(throws: MockCredentialProviderError.self) {
            try await provider.sign(payload: Data([0x01]), documentID: "any")
        }
    }

    // MARK: Signing Failure Strategy (alwaysFail)

    @Test("Always-fail strategy throws signingFailed on first call")
    func alwaysFailThrowsOnFirstCall() async {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .alwaysFail
        )

        // When / Then
        await #expect(throws: MockSignFailedError.signingFailed) {
            try await provider.sign(payload: Data([0x01]), documentID: "test-id")
        }
    }

    @Test("Always-fail strategy throws signingFailed on every subsequent call")
    func alwaysFailThrowsOnEveryCall() async {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .alwaysFail
        )

        // When / Then — call multiple times, all should throw
        for _ in 1...3 {
            await #expect(throws: MockSignFailedError.signingFailed) {
                try await provider.sign(payload: Data([0x01]), documentID: "test-id")
            }
        }
    }

    @Test("Always-fail strategy still returns credential from getCredentials")
    func alwaysFailStillReturnsCredential() async throws {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .alwaysFail
        )

        // When
        let credentials = try await provider.getCredentials(for: CredentialRequest(documentTypes: []))

        // Then
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "test-id")
    }

    // MARK: Authentication Cancelled Once Strategy (failOnceThenSucceed)

    @Test("Fail-once strategy throws localAuthenticationCancelled on first call")
    func failOnceThrowsOnFirstCall() async {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .failOnceThenSucceed
        )

        // When / Then
        await #expect(throws: MockLocalAuthCancelledError.cancelled) {
            try await provider.sign(payload: Data([0x01]), documentID: "test-id")
        }
    }

    @Test("Fail-once strategy signs successfully on second call")
    func failOnceSignsOnSecondCall() async throws {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .failOnceThenSucceed
        )
        let payload = Data("device-authentication-payload".utf8)

        // First call throws localAuthenticationCancelled
        await #expect(throws: MockLocalAuthCancelledError.cancelled) {
            try await provider.sign(payload: payload, documentID: "test-id")
        }

        // When — second call
        let signatureData = try await provider.sign(payload: payload, documentID: "test-id")

        // Then
        let publicKey = try P256.Signing.PrivateKey(
            rawRepresentation: testCredential.privateKey
        ).publicKey
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
        #expect(publicKey.isValidSignature(signature, for: payload))
    }

    @Test("Fail-once strategy signs successfully on third and subsequent calls")
    func failOnceSignsOnSubsequentCalls() async throws {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .failOnceThenSucceed
        )
        let payload = Data("test-payload".utf8)

        // First call throws localAuthenticationCancelled
        await #expect(throws: MockLocalAuthCancelledError.cancelled) {
            try await provider.sign(payload: payload, documentID: "test-id")
        }

        // When — third call (second success)
        _ = try await provider.sign(payload: payload, documentID: "test-id")
        let signatureData = try await provider.sign(payload: payload, documentID: "test-id")

        // Then
        let publicKey = try P256.Signing.PrivateKey(
            rawRepresentation: testCredential.privateKey
        ).publicKey
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
        #expect(publicKey.isValidSignature(signature, for: payload))
    }

    @Test("Fail-once strategy still returns credential from getCredentials")
    func failOnceStillReturnsCredential() async throws {
        // Given
        let provider = MockCredentialProvider(
            activeCredential: testCredential,
            signingStrategy: .failOnceThenSucceed
        )

        // When
        let credentials = try await provider.getCredentials(for: CredentialRequest(documentTypes: []))

        // Then
        #expect(credentials.count == 1)
        #expect(credentials.first?.id == "test-id")
    }

    // MARK: - Success Strategy (default)

    @Test("Success strategy signs normally by default")
    func successStrategySignsNormally() async throws {
        // Given — no explicit strategy, defaults to .success
        let provider = MockCredentialProvider(activeCredential: testCredential)
        let payload = Data("payload".utf8)

        // When
        let signatureData = try await provider.sign(payload: payload, documentID: "test-id")

        // Then
        let publicKey = try P256.Signing.PrivateKey(
            rawRepresentation: testCredential.privateKey
        ).publicKey
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)
        #expect(publicKey.isValidSignature(signature, for: payload))
    }
}
