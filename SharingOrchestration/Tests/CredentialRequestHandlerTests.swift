import Foundation
import SharingCryptoService
@testable import SharingOrchestration
import Testing

@MainActor
@Suite("CredentialRequestHandler Tests")
struct CredentialRequestHandlerTests {
    // swiftlint:disable:next line_length
    private static let validDeviceRequestCBOR = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"

    // rawCredential with MSO docType = "org.iso.18013.5.1.mDL"
    private static let validRawCredential = Data(base64Encoded:
        "ompuYW1lU3BhY2VzoGppc3N1ZXJBdXRohEChGCFAWCPYGFgfoWdkb2NUeXBldW9yZy5pc28uMTgwMTMuNS4xLm1ETEA="
    )!

    // rawCredential with MSO docType = "org.wrong.docType"
    private static let mismatchedRawCredential = Data(base64Encoded:
        "ompuYW1lU3BhY2VzoGppc3N1ZXJBdXRohEChGCFAWCvYGFgnoWdkb2NUeXBleBxvcmcuaXNvLjE4MDEzLjUuMS5taXNtYXRjaGVkQA=="
    )!

    private func createDeviceRequest() throws -> DeviceRequest {
        try DeviceRequest(data: try #require(Data(base64URLEncoded: Self.validDeviceRequestCBOR)))
    }

    // MARK: - Successful Credential Fetch & DocType Match
    @Test("requestAndValidate succeeds when credential docType matches request")
    func successfulValidation() async throws {
        let provider = MockProvider(credentials: [
            Credential(id: "test", rawCredential: Self.validRawCredential)
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: Never.self) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }

    @Test("requestAndValidate selects only the first credential when multiple returned")
    func selectsFirstCredential() async throws {
        let provider = MockProvider(credentials: [
            Credential(id: "first", rawCredential: Self.validRawCredential),
            Credential(id: "second", rawCredential: Self.mismatchedRawCredential)
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: Never.self) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }

    // MARK: - MSO Decode Failure
    @Test("requestAndValidate throws msoDecodingFailed when rawCredential is malformed")
    func msoDecodeFailure() async throws {
        let provider = MockProvider(credentials: [
            Credential(id: "malformed", rawCredential: Data([0x01, 0x02, 0x03]))
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.msoDecodingFailed) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }

    // MARK: - Host App Throws Error
    @Test("requestAndValidate throws getCredentialsError when provider throws")
    func providerThrows() async throws {
        let provider = MockProvider(shouldThrow: true)
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.getCredentialsError) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }

    // MARK: - Zero Credentials Returned
    @Test("requestAndValidate throws noCredentialsReturned when provider returns empty array")
    func emptyCredentials() async throws {
        let provider = MockProvider(credentials: [])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.noCredentialsReturned) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }

    // MARK: - DocType Mismatch
    @Test("requestAndValidate throws docTypeMismatch when MSO docType does not match request")
    func docTypeMismatch() async throws {
        let provider = MockProvider(credentials: [
            Credential(id: "wrong", rawCredential: Self.mismatchedRawCredential)
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.docTypeMismatch) {
            try await sut.requestAndValidate(for: deviceRequest)
        }
    }
}

// MARK: - Mock CredentialProvider
private final class MockProvider: CredentialProvider {
    private let credentials: [Credential]
    private let shouldThrow: Bool

    init(credentials: [Credential] = [], shouldThrow: Bool = false) {
        self.credentials = credentials
        self.shouldThrow = shouldThrow
    }

    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return credentials
    }

    func sign(payload: Data, documentID: String) async throws -> Data {
        Data()
    }
}
