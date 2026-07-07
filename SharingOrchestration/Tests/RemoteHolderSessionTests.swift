import Foundation
import SharingCryptoService
@testable import SharingOrchestration
import SharingValidationService
import Testing

@Suite("RemoteHolderSession Tests")
struct RemoteHolderSessionTests {
    private func makeValidatedRequest() throws -> ValidatedRequest {
        ValidatedRequest(
            dcqlQuery: DCQLQuery(credentials: [], credentialSets: nil),
            responseURI: try #require(URL(string: "https://verifier.example.com/response")),
            state: nil,
            nonce: "abc123",
            clientIdentifierPrefix: .x509SanDns(identifier: "verifier.example.com")
        )
    }

    private func makeDeviceRequest() -> DeviceRequest {
        DeviceRequest(docRequests: [
            DocRequest(itemsRequest: ItemsRequest(docType: .mdl, nameSpaces: []))
        ])
    }

    // MARK: - transition

    @Test("Legal transition updates the current state")
    func legalTransitionSucceeds() throws {
        let sut = RemoteHolderSession()

        try sut.transition(to: .remoteFetchingRequest)

        #expect(sut.currentState == .remoteFetchingRequest)
    }

    @Test("Illegal transition throws and leaves state unchanged")
    func illegalTransitionThrows() {
        let sut = RemoteHolderSession()

        #expect(throws: HolderSessionTransitionError.self) {
            // .notStarted cannot jump straight to .awaitingUserConsent
            try sut.transition(to: .awaitingUserConsent(makeDeviceRequest()))
        }
        #expect(sut.currentState == .notStarted)
    }

    // MARK: - setValidatedRequest

    @Test("setValidatedRequest stores the request when in remoteValidatingRequest state")
    func setValidatedRequestSucceeds() throws {
        let sut = RemoteHolderSession()
        try sut.transition(to: .remoteFetchingRequest)
        try sut.transition(to: .remoteValidatingRequest)

        let validatedRequest = try makeValidatedRequest()
        let deviceRequest = makeDeviceRequest()
        try sut.setValidatedRequest(validatedRequest, deviceRequest: deviceRequest)

        #expect(sut.validatedRequest == validatedRequest)
        #expect(sut.deviceRequest == deviceRequest)
    }

    @Test("setValidatedRequest throws when called from the wrong state")
    func setValidatedRequestThrowsFromWrongState() {
        let sut = RemoteHolderSession()

        #expect(throws: SessionError.incorrectSessionState(HolderSessionStateKind.notStarted.rawValue)) {
            try sut.setValidatedRequest(makeValidatedRequest(), deviceRequest: makeDeviceRequest())
        }
        #expect(sut.validatedRequest == nil)
        #expect(sut.deviceRequest == nil)
    }
}
