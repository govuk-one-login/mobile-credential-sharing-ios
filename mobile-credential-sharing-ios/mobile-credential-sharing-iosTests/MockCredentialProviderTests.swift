import CredentialSharingUI
import CryptoKit
import Foundation
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

    // MARK: - AC1: Provider Initialisation

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

    // MARK: - AC2: getCredentials

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

    // MARK: - AC3: sign

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
}
