import Foundation
import SharingCryptoService
@testable import SharingOrchestration
import Testing
import UIKit

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

    // rawCredential with nameSpaces containing a matching element (family_name)
    private static let rawCredentialWithNameSpaces = Data(base64Encoded:
        // swiftlint:disable:next line_length
        "ompuYW1lU3BhY2VzoXFvcmcuaXNvLjE4MDEzLjUuMYHYGFhHpGhkaWdlc3RJRABmcmFuZG9tQwECA3FlbGVtZW50SWRlbnRpZmllcmtmYW1pbHlfbmFtZWxlbGVtZW50VmFsdWVlU21pdGhqaXNzdWVyQXV0aIP29lgj2BhYH6FnZG9jVHlwZXVvcmcuaXNvLjE4MDEzLjUuMS5tREw="
    )!

    // rawCredential with a namespace that doesn't match the DeviceRequest
    private static let rawCredentialWithNonMatchingNameSpace = Data(base64Encoded:
        // swiftlint:disable:next line_length
        "ompuYW1lU3BhY2VzoXVvcmcudW5rbm93bi5uYW1lc3BhY2WB2BhYR6RoZGlnZXN0SUQAZnJhbmRvbUMBAgNxZWxlbWVudElkZW50aWZpZXJrZmFtaWx5X25hbWVsZWxlbWVudFZhbHVlZVNtaXRoamlzc3VlckF1dGiD9vZYI9gYWB+hZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURM"
    )!

    // rawCredential with correct namespace but no matching element identifiers
    private static let rawCredentialWithNoMatchingElements = Data(base64Encoded:
        // swiftlint:disable:next line_length
        "ompuYW1lU3BhY2VzoXFvcmcuaXNvLjE4MDEzLjUuMYHYGFhLpGhkaWdlc3RJRABmcmFuZG9tQwECA3FlbGVtZW50SWRlbnRpZmllcm91bnJlbGF0ZWRfZmllbGRsZWxlbWVudFZhbHVlZXZhbHVlamlzc3VlckF1dGiD9vZYI9gYWB+hZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURM"
    )!

    let session = MockCredentialSession()

    private func createDeviceRequest() throws -> DeviceRequest {
        try DeviceRequest(data: try #require(Data(base64URLEncoded: Self.validDeviceRequestCBOR)))
    }

    // MARK: - Successful Credential Fetch & DocType Match
    @Test("requestAndValidate succeeds when credential docType matches request")
    func successfulValidation() async throws {
        let mockCredential = Credential(id: "test", rawCredential: Self.validRawCredential)
        let provider = MockProvider(credentials: [
            mockCredential
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: Never.self) {
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
        }
        
        #expect(session.matchedCredential?.id == mockCredential.id)
    }

    @Test("requestAndValidate selects only the first credential when multiple returned")
    func selectsFirstCredential() async throws {
        let firstCred = Credential(id: "first", rawCredential: Self.validRawCredential)
        let secondCred = Credential(id: "second", rawCredential: Self.mismatchedRawCredential)
        
        let provider = MockProvider(credentials: [
            firstCred,
            secondCred
        ])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: Never.self) {
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
        }
        
        #expect(session.matchedCredential?.id == firstCred.id)
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
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
        }
    }

    // MARK: - Host App Throws Error
    @Test("requestAndValidate throws getCredentialsError when provider throws")
    func providerThrows() async throws {
        let provider = MockProvider(shouldThrow: true)
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.getCredentialsError) {
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
        }
    }

    // MARK: - Zero Credentials Returned
    @Test("requestAndValidate throws noCredentialsReturned when provider returns empty array")
    func emptyCredentials() async throws {
        let provider = MockProvider(credentials: [])
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()

        await #expect(throws: CredentialRequestError.noCredentialsReturned) {
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
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
            try await sut.requestAndValidateCredential(for: deviceRequest, in: session)
        }
    }

    // MARK: - Sign
    @Test("signDeviceAuthenticationBytes delegates to credentialProvider and stores signature on session")
    func signDeviceAuthenticationBytesDelegatesToProvider() async throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let mockSession = MockSigningSession(
            deviceAuthenticationBytes: Data([0x01, 0x02, 0x03]),
            matchedCredential: Credential(id: "doc-123", rawCredential: Data())
        )

        try await sut.signDeviceAuthenticationBytes(in: mockSession)

        #expect(provider.signedPayload == Data([0x01, 0x02, 0x03]))
        #expect(provider.signedDocumentID == "doc-123")
        #expect(mockSession.signatureBytes == Data([0xAA, 0xBB]))
    }

    @Test("signDeviceAuthenticationBytes throws when deviceAuthenticationBytes is nil")
    func signThrowsWhenNoDeviceAuthBytes() async throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let mockSession = MockSigningSession(
            deviceAuthenticationBytes: nil,
            matchedCredential: Credential(id: "doc-123", rawCredential: Data())
        )

        await #expect(throws: CryptoServiceError.deviceAuthenticationElementsNotFound) {
            try await sut.signDeviceAuthenticationBytes(in: mockSession)
        }
    }

    @Test("signDeviceAuthenticationBytes throws when matchedCredential is nil")
    func signThrowsWhenNoMatchedCredential() async throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let mockSession = MockSigningSession(
            deviceAuthenticationBytes: Data([0x01]),
            matchedCredential: nil
        )

        await #expect(throws: CredentialRequestError.matchedCredentialNotFound) {
            try await sut.signDeviceAuthenticationBytes(in: mockSession)
        }
    }

    // MARK: - filterIssuerSigned
    @Test("filterIssuerSigned throws matchedCredentialNotFound when session has no matched credential")
    func filterThrowsWhenNoMatchedCredential() throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()
        let session = MockCredentialSession()

        #expect(throws: CredentialRequestError.matchedCredentialNotFound) {
            try sut.filterIssuerSigned(for: deviceRequest, in: session)
        }
    }

    @Test("filterIssuerSigned sets issuerSigned on session when filtering succeeds")
    func filterSetsIssuerSignedOnSuccess() throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()
        let session = MockCredentialSession()
        session.matchedCredential = Credential(
            id: "test",
            rawCredential: Self.rawCredentialWithNameSpaces
        )

        try sut.filterIssuerSigned(for: deviceRequest, in: session)

        #expect(session.issuerSigned != nil)
    }

    @Test("filterIssuerSigned throws when credential has no matching namespaces")
    func filterThrowsNoMatchingNameSpaces() throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()
        let session = MockCredentialSession()
        session.matchedCredential = Credential(
            id: "test",
            rawCredential: Self.rawCredentialWithNonMatchingNameSpace
        )

        #expect(throws: IssuerSignedFilterError.noMatchingNameSpaces) {
            try sut.filterIssuerSigned(for: deviceRequest, in: session)
        }
    }

    @Test("filterIssuerSigned throws when namespace matches but no elements match")
    func filterThrowsNoMatchingAttributes() throws {
        let provider = MockProvider()
        let sut = CredentialRequestHandler(credentialProvider: provider)
        let deviceRequest = try createDeviceRequest()
        let session = MockCredentialSession()
        session.matchedCredential = Credential(
            id: "test",
            rawCredential: Self.rawCredentialWithNoMatchingElements
        )

        #expect(throws: IssuerSignedFilterError.noMatchingAttributes) {
            try sut.filterIssuerSigned(for: deviceRequest, in: session)
        }
    }
}

// MARK: - Mock CredentialProvider
private final class MockProvider: CredentialProvider {
    private let credentials: [Credential]
    private let shouldThrow: Bool
    private let stubbedSignature: Data
    var signedPayload: Data?
    var signedDocumentID: String?

    init(
        credentials: [Credential] = [],
        shouldThrow: Bool = false,
        stubbedSignature: Data = Data([0xAA, 0xBB])
    ) {
        self.credentials = credentials
        self.shouldThrow = shouldThrow
        self.stubbedSignature = stubbedSignature
    }

    func getCredentials(for request: CredentialRequest) async throws -> [Credential] {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return credentials
    }

    func sign(payload: Data, documentID: String) async throws -> Data {
        if shouldThrow { throw NSError(domain: "test", code: 2) }
        signedPayload = payload
        signedDocumentID = documentID
        return stubbedSignature
    }
}

// MARK: - Mock CredentialSession
class MockCredentialSession: CredentialSessionProtocol {
    var matchedCredential: Credential?
    var issuerSigned: SharingCryptoService.IssuerSigned?
    
    func setMatchedCredential(_ credential: SharingOrchestration.Credential) throws {
        matchedCredential = credential
    }
    
    func setIssuerSigned(_ issuerSigned: SharingCryptoService.IssuerSigned) throws {
        self.issuerSigned = issuerSigned
    }
}

// MARK: - Mock Signing Session
private final class MockSigningSession: CryptoHolderSessionProtocol, CredentialSessionProtocol {
    var cryptoContext: CryptoContext?
    var qrCode: UIImage?
    var skReaderMessageCounter = 1
    var skDeviceMessageCounter = 1
    var sessionTranscript: SessionTranscript?
    var docType: DocType?
    var deviceAuthenticationBytes: Data?
    var signatureBytes: Data?
    var deviceSigned: DeviceSigned?
    var matchedCredential: Credential?
    var issuerSigned: SharingCryptoService.IssuerSigned?

    init(deviceAuthenticationBytes: Data?, matchedCredential: Credential?) {
        self.deviceAuthenticationBytes = deviceAuthenticationBytes
        self.matchedCredential = matchedCredential
    }

    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws {}
    func setSKDeviceKey(_ key: [UInt8]) throws {}
    func setSessionTranscriptAndDocType(sessionTranscript: SessionTranscript, docType: DocType) throws {}
    func setDeviceAuthenticationBytes(_ bytes: Data) throws { deviceAuthenticationBytes = bytes }
    func setSignatureBytes(_ bytes: Data) throws { signatureBytes = bytes }
    func setDeviceSigned(deviceSigned: DeviceSigned) throws { self.deviceSigned = deviceSigned }
    func setMatchedCredential(_ credential: Credential) throws { matchedCredential = credential }
    func setIssuerSigned(_ issuerSigned: SharingCryptoService.IssuerSigned) throws {
        self.issuerSigned = issuerSigned
    }
}
