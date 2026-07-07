import Foundation
import SharingCryptoService
import SharingNetworkTransport
import SharingPrerequisiteGate
import SharingValidationService

/// Orchestrates the OID4VP (Remote) presentation flow initiated by an `openid4vp://` deeplink.
///
/// Mirrors `ISOHolderOrchestrator` but drives the request-side pipeline: parse the engagement URI,
/// fetch and verify the signed Authorization Request Object, validate it, map the DCQL query to an
/// ISO `DeviceRequest`, then await user consent.
///
/// Response building/encryption/submission (Steps 9–16) is not yet implemented; `userDidApprove()`
/// is a deliberate stub.
@MainActor
public class RemoteHolderOrchestrator: HolderOrchestratorProtocol {
    private(set) var session: RemoteHolderSessionProtocol?
    public weak var delegate: HolderOrchestratorDelegate?

    private let deeplink: URL
    private let remoteTransport: RemoteTransportProtocol
    private let uriParser: URIParser
    private let signatureVerifier: SignatureVerifying
    private let requestValidator: RequestValidator
    private let dcqlMapper: DCQLMapper

    public init(
        deeplink: URL,
        remoteTransport: RemoteTransportProtocol,
        uriParser: URIParser = URIParser(),
        signatureVerifier: SignatureVerifying = JWTSignatureVerifier(),
        requestValidator: RequestValidator = RequestValidator(),
        dcqlMapper: DCQLMapper = DCQLMapper()
    ) {
        self.deeplink = deeplink
        self.remoteTransport = remoteTransport
        self.uriParser = uriParser
        self.signatureVerifier = signatureVerifier
        self.requestValidator = requestValidator
        self.dcqlMapper = dcqlMapper
    }

    public func start() {
        print("Remote Presentation Session started")
        Task {
            await processRequest()
        }
    }

    func processRequest() async {
        if session == nil {
            session = RemoteHolderSession()
        }
        guard let session = getSession() else { return }
        do {
            let uriMetadata = try uriParser.parse(uri: deeplink)

            try session.transition(to: .remoteFetchingRequest)
            delegate?.orchestrator(didUpdateState: session.currentState)

            let jwt = try await remoteTransport.fetchRequestObject(from: uriMetadata.requestURI)

            try session.transition(to: .remoteValidatingRequest)
            delegate?.orchestrator(didUpdateState: session.currentState)

            let verifiedJWT = try signatureVerifier.verify(jwt: jwt)
            let requestObject = try VerifiedRequestObject(
                headerData: verifiedJWT.headerData,
                payloadData: verifiedJWT.payloadData,
                leafCertificateSANs: verifiedJWT.leafCertificateSANs
            )
            let validatedRequest = try requestValidator.validate(
                requestObject: requestObject,
                uriMetadata: uriMetadata
            )

            let deviceRequest = try buildDeviceRequest(from: validatedRequest)
            try session.setValidatedRequest(validatedRequest, deviceRequest: deviceRequest)

            try session.transition(to: .awaitingUserConsent(deviceRequest))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            handleFailure(error)
        }
    }

    /// The `RequestValidator` guarantees at least one `mso_mdoc` credential query survives, so the
    /// PoC maps the first one to a single-document `DeviceRequest`.
    private func buildDeviceRequest(from request: ValidatedRequest) throws -> DeviceRequest {
        guard let credential = request.dcqlQuery.credentials.first else {
            throw SessionError.generic("No credential query in validated request")
        }
        let itemsRequest = try dcqlMapper.mapToItemsRequest(credential)
        return DeviceRequest(docRequests: [DocRequest(itemsRequest: itemsRequest)])
    }

    public func userDidApprove() {
        guard let session = getSession() else { return }
        // TODO: DCMAW-21231 — build the DeviceResponse, sign DeviceAuth, JWE-encrypt and
        // POST to response_uri. Until then approving cannot complete the flow.
        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            try session.transition(to: .failed(.generic("Response building not yet implemented")))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            handleFailure(error)
        }
    }

    public func userDidDeny() {
        transitionToCancel()
        session = nil
    }

    public func cancel() {
        transitionToCancel()
        session = nil
    }

    public func resolve(_: MissingPrerequisite) {
        // Remote flow has no prerequisite gate; nothing to resolve.
    }

    private func transitionToCancel() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .cancelled)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    private func handleFailure(_ error: Error) {
        let sessionError = (error as? SessionError) ?? .generic(error.localizedDescription)
        try? session?.transition(to: .failed(sessionError))
        delegate?.orchestrator(didUpdateState: .failed(sessionError))
    }

    private func getSession() -> RemoteHolderSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}
