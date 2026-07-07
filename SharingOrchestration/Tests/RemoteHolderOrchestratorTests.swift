import Foundation
import SharingCryptoService
import SharingNetworkTransport
@testable import SharingOrchestration
import SharingValidationService
import Testing

@MainActor
@Suite("RemoteHolderOrchestrator Tests")
struct RemoteHolderOrchestratorTests {
    // A well-formed engagement URI whose client_id matches the request object's SAN + client_id.
    let deeplink = URL(string: "openid4vp://?client_id=x509_san_dns%3Averifier.example.com"
        + "&response_type=vp_token&nonce=abc123&request_uri=https%3A%2F%2Fverifier.example.com%2Freq")!

    private func makeVerifiedJWT() -> VerifiedJWT {
        let header = Data(#"{"typ":"oauth-authz-req+jwt","alg":"ES256"}"#.utf8)
        let payload = Data("""
        {
            "aud": "https://self-issued.me/v2",
            "client_id": "x509_san_dns:verifier.example.com",
            "response_type": "vp_token",
            "response_mode": "direct_post.jwt",
            "response_uri": "https://verifier.example.com/response",
            "nonce": "abc123",
            "client_metadata": { "jwks": { "keys": [] } },
            "dcql_query": {
                "credentials": [
                    {
                        "id": "mdl",
                        "format": "mso_mdoc",
                        "meta": { "doctype_value": "org.iso.18013.5.1.mDL" },
                        "claims": [
                            { "path": ["org.iso.18013.5.1", "family_name"] },
                            { "path": ["org.iso.18013.5.1", "given_name"] }
                        ]
                    }
                ]
            }
        }
        """.utf8)
        return VerifiedJWT(
            headerData: header,
            payloadData: payload,
            leafCertificateSANs: ["verifier.example.com"]
        )
    }

    private func makeSUT(
        transport: RemoteTransportProtocol,
        verifier: SignatureVerifying
    ) -> (RemoteHolderOrchestrator, RecordingDelegate) {
        let sut = RemoteHolderOrchestrator(
            deeplink: deeplink,
            remoteTransport: transport,
            signatureVerifier: verifier
        )
        let delegate = RecordingDelegate()
        sut.delegate = delegate
        return (sut, delegate)
    }

    // MARK: - Happy Path

    @Test("Runs fetch → validate → awaitingUserConsent and stores the mapped DeviceRequest")
    func happyPath() async throws {
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(jwt: "any.jwt.value"),
            verifier: StubSignatureVerifier(result: .success(makeVerifiedJWT()))
        )

        await sut.processRequest()

        #expect(delegate.states.map(\.kind) == [.remoteFetchingRequest, .remoteValidatingRequest, .awaitingUserConsent])
        guard case let .awaitingUserConsent(deviceRequest) = sut.session?.currentState else {
            Issue.record("Expected awaitingUserConsent")
            return
        }
        #expect(deviceRequest.docRequests.first?.itemsRequest.docType == .mdl)
        #expect(deviceRequest.docRequests.first?.itemsRequest.nameSpaces.first?.elements.map(\.identifier)
            == ["family_name", "given_name"])
    }

    // MARK: - Failure Paths

    @Test("Fetch error transitions to failed")
    func fetchErrorFails() async {
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(error: URLError(.notConnectedToInternet)),
            verifier: StubSignatureVerifier(result: .success(makeVerifiedJWT()))
        )

        await sut.processRequest()

        #expect(delegate.states.last?.kind == .failed)
    }

    @Test("Signature verification failure transitions to failed")
    func verificationFailureFails() async {
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(jwt: "any.jwt.value"),
            verifier: StubSignatureVerifier(result: .failure(.invalidSignature))
        )

        await sut.processRequest()

        #expect(delegate.states.last?.kind == .failed)
    }

    @Test("Validation failure (wrong audience) transitions to failed")
    func validationFailureFails() async {
        let header = Data(#"{"typ":"oauth-authz-req+jwt","alg":"ES256"}"#.utf8)
        let payload = Data(#"{"aud":"wrong","response_type":"vp_token"}"#.utf8)
        let badJWT = VerifiedJWT(headerData: header, payloadData: payload, leafCertificateSANs: [])
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(jwt: "any.jwt.value"),
            verifier: StubSignatureVerifier(result: .success(badJWT))
        )

        await sut.processRequest()

        #expect(delegate.states.last?.kind == .failed)
    }

    @Test("Malformed deeplink (missing scheme) transitions to failed before fetching")
    func malformedDeeplinkFails() async {
        let sut = RemoteHolderOrchestrator(
            deeplink: URL(string: "https://not-openid4vp.example.com")!,
            remoteTransport: StubRemoteTransport(jwt: "any.jwt.value"),
            signatureVerifier: StubSignatureVerifier(result: .success(makeVerifiedJWT()))
        )
        let delegate = RecordingDelegate()
        sut.delegate = delegate

        await sut.processRequest()

        #expect(delegate.states.map(\.kind) == [.failed])
    }

    // MARK: - User Decision

    @Test("userDidApprove stubs out to failed until response building exists")
    func approveStubsToFailed() async {
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(jwt: "any.jwt.value"),
            verifier: StubSignatureVerifier(result: .success(makeVerifiedJWT()))
        )
        await sut.processRequest()

        sut.userDidApprove()

        #expect(delegate.states.last?.kind == .failed)
    }

    @Test("userDidDeny transitions to cancelled and clears the session")
    func denyCancels() async {
        let (sut, delegate) = makeSUT(
            transport: StubRemoteTransport(jwt: "any.jwt.value"),
            verifier: StubSignatureVerifier(result: .success(makeVerifiedJWT()))
        )
        await sut.processRequest()

        sut.userDidDeny()

        #expect(delegate.states.last?.kind == .cancelled)
        #expect(sut.session == nil)
    }
}

// MARK: - Test doubles

private final class RecordingDelegate: HolderOrchestratorDelegate {
    var states: [HolderSessionState] = []
    
    func orchestrator(didUpdateState state: HolderSessionState?) {
        if let state {
            states.append(state)
        }
    }
}

private struct StubRemoteTransport: RemoteTransportProtocol {
    var jwt: String?
    var error: (any Error & Sendable)?

    init(jwt: String) {
        self.jwt = jwt
    }
    
    init(error: any Error & Sendable) {
        self.error = error
    }

    func fetchRequestObject(from requestURI: URL) async throws -> String {
        if let error { throw error }
        return jwt ?? ""
    }

    func submitResponse(vpToken: String, state: String?, to responseURI: URL) async throws -> URL? {
        nil
    }
}

private struct StubSignatureVerifier: SignatureVerifying {
    let result: Result<VerifiedJWT, JWTVerificationError>

    func verify(jwt: String) throws(JWTVerificationError) -> VerifiedJWT {
        switch result {
        case let .success(verified): return verified
        case let .failure(error): throw error
        }
    }
}
