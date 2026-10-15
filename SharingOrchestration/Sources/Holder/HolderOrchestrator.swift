import CoreBluetooth
import ExchangeFormat
import Foundation
import ReaderAuthentication
import SharingBluetoothTransport
import SharingCryptoService
import SharingLogging
import SharingPrerequisiteGate
import SwiftCBOR
import UIKit
import X509

// swiftlint:disable file_length
@MainActor
public protocol HolderOrchestratorProtocol {
    var delegate: HolderOrchestratorDelegate? { get set }
    func startPresentation()
    func userDidTapCancel()
    func userDidConfirmCancel()
    func resolve(_ missingPrerequisite: MissingPrerequisite)
    func userDidTapApprove()
    func userDidTapDeny()
    func qrCodeGenerationDidFail()
}

public protocol HolderOrchestratorDelegate: AnyObject {
    func orchestrator(didUpdateState state: HolderSessionState?)
    func orchestratorDidRequestCancelConfirmation()
}

@MainActor
// swiftlint:disable:next type_body_length
public class HolderOrchestrator: @MainActor HolderOrchestratorProtocol {
    /// Buffer between send-completion and GATT End to allow the peer time to receive and process the preceding SessionData.
    private static let gattEndDelay: Int = 500

    /// The document types this product supports. Reader Authentication keeps only
    /// candidates whose `docType` is in this set. Currently mDL only.
    public static let productSupportedDocumentTypes: Set<String> = [DocType.mdl.rawValue]

    private(set) var session: HolderSessionProtocol?
    public weak var delegate: HolderOrchestratorDelegate?
    
    // We must maintain a strong reference to PrerequisiteGate to enable the CoreBluetooth OS prompt to be displayed
    private(set) var prerequisiteGate: PrerequisiteGateProtocol?
    private(set) var cryptoService: CryptoServiceProtocol?
    private(set) var bluetoothTransport: BluetoothTransportProtocol?
    private(set) var credentialRequestHandler: CredentialRequestHandlerProtocol
    private(set) var inactivityTimer: InactivityTimerProtocol?
    /// Timer that periodically refreshes the engagement QR code while the Holder is presenting.
    private(set) var engagementRefreshTimer: InactivityTimerProtocol?

    // Reader Authentication collaborator and its captured, immutable inputs.
    private(set) var readerAuthenticator: ReaderAuthenticating
    private(set) var trustedReaderCertificates: [Certificate]
    private(set) var supportedDocumentTypes: Set<String>

    /// Privacy-policy URL used only by the EX1 empty-trust admission path, where
    /// there is no verified reader certificate to supply one. Injected by the
    /// Consumer (via `CredentialPresenter`, sourced from the app's Info.plist) so
    /// the SDK holds no hardcoded URI. In the main flow the privacy-policy URL is
    /// supplied by the verified reader certificate instead. Temporary EX1 artifact
    /// (removed in DCMAW-23451).
    private(set) var syntheticPrivacyPolicyURL: URL?

    private var sendCompletion: (() -> Void)?
    
    public init(
        credentialRequestHandler: CredentialRequestHandlerProtocol,
        readerAuthenticator: ReaderAuthenticating = ReaderAuthenticationVerifier(),
        trustedReaderCertificates: [Certificate],
        supportedDocumentTypes: Set<String>,
        syntheticPrivacyPolicyURL: URL? = nil
    ) {
        self.credentialRequestHandler = credentialRequestHandler
        self.readerAuthenticator = readerAuthenticator
        self.trustedReaderCertificates = trustedReaderCertificates
        self.supportedDocumentTypes = supportedDocumentTypes
        self.syntheticPrivacyPolicyURL = syntheticPrivacyPolicyURL
    }
    
    init(prerequisiteGate: PrerequisiteGateProtocol? = nil,
         bluetoothTransport: BluetoothTransportProtocol? = nil,
         cryptoService: CryptoServiceProtocol? = nil,
         credentialRequestHandler: CredentialRequestHandlerProtocol,
         inactivityTimer: InactivityTimerProtocol? = nil,
         engagementRefreshTimer: InactivityTimerProtocol? = nil,
         readerAuthenticator: ReaderAuthenticating = ReaderAuthenticationVerifier(),
         trustedReaderCertificates: [Certificate] = [],
         supportedDocumentTypes: Set<String> = [],
         syntheticPrivacyPolicyURL: URL? = nil) {
        self.prerequisiteGate = prerequisiteGate
        self.bluetoothTransport = bluetoothTransport
        self.cryptoService = cryptoService
        self.credentialRequestHandler = credentialRequestHandler
        self.inactivityTimer = inactivityTimer
        self.engagementRefreshTimer = engagementRefreshTimer
        self.readerAuthenticator = readerAuthenticator
        self.trustedReaderCertificates = trustedReaderCertificates
        self.supportedDocumentTypes = supportedDocumentTypes
        self.syntheticPrivacyPolicyURL = syntheticPrivacyPolicyURL
        self.bluetoothTransport?.delegate = self
    }
    
    public func startPresentation() {
        session = HolderSession()
        Logger.log("Holder Presentation Session started")
        
        // MARK: - Pre-flight Checks
        performPreflightChecks()
    }

    func performPreflightChecks() {
        if prerequisiteGate == nil {
            prerequisiteGate = PrerequisiteGate()
        }
        guard let prerequisiteGate = prerequisiteGate else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("PrerequisiteGate is not available.")))
            return
        }
        do {
            let missingPrerequisites = prerequisiteGate.evaluatePrerequisites(
                for: [.bluetooth]
            ) {
                self.performPreflightChecks()
            }
            if missingPrerequisites.isEmpty {
                try session?.transition(to: .readyToPresent)
                
                // MARK: - Initialisation & Device Engagement
                prepareEngagement()
                
            } else {
                let bluetoothStateIsUnknown = missingPrerequisites.contains {
                    if case .bluetooth(.stateUnknown) = $0 { return true }
                    return false
                }

                // CBPeripheralManager has not fully initialised yet;
                // wait for the delegate to report a state change and re-run preflight checks
                guard !bluetoothStateIsUnknown else { return }

                if let unrecoverablePrerequisite = missingPrerequisites.first(where: { !$0.isRecoverable }) {
                    try session?.transition(
                        to: .failed(.unrecoverablePrerequisite(unrecoverablePrerequisite))
                    )
                    delegate?
                        .orchestrator(didUpdateState: session?.currentState)
                    return
                }
                try session?.transition(
                    to: .preflight(missingPrerequisites: missingPrerequisites)
                )
                delegate?
                    .orchestrator(didUpdateState: session?.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
        
    }
    
    func prepareEngagement() {
        let sessionDecryption = SessionDecryption()
        if cryptoService == nil {
            cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        }
        
        guard let session = getSession() else { return }
        
        do {
            try cryptoService?.prepareEngagement(in: session)
            guard session.cryptoContext != nil,
                  session.qrPayload != nil,
                  session.serviceUUID != nil else {
                delegate?.orchestrator(
                    didUpdateState: .failed(.generic("Session engagement failed to prepare correctly."))
                )
                return
            }
                        
            if bluetoothTransport == nil {
                bluetoothTransport = BluetoothTransport()
                bluetoothTransport?.delegate = self
            }
           
            try bluetoothTransport?.startAdvertising(in: session)
            // Once .startAdvertising has been called, we must wait for the delegate function to detect that it was successful, call presentQRCode & transition to the new state
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func presentQRCode() {
        guard let qrPayload = session?.qrPayload else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("QR Code failed to generate.")))
            return
        }
        
        do {
            let engagementPresentation = EngagementPresentation(qrPayload: qrPayload, cancelRequiresConfirmation: false)
            
            try session?.transition(to: .presentingEngagement(engagementPresentation))
            delegate?.orchestrator(didUpdateState: session?.currentState)
            
            startEngagementRefreshTimer()
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    // MARK: - Transport & Data
    private func didFailTransport(with error: BluetoothTransportError) {
        guard let session,
              session.currentState.isActiveState else {
            return
        }
        
        try? session.transition(to: .failed(.generic(error.errorDescription ?? "Unknown error")))
        delegate?.orchestrator(didUpdateState: session.currentState)
        tearDownSession(andNotify: false)
    }
    
    private func connectionDidConnect() {
        guard let session = getSession() else { return }
        
        do {
            // TODO: DCMAW-18497 Look into changing the behaviour of connectionDidConnect within BLEPeripheralTransport .handleDidSubscribe() to avoid this check
            if session.currentState != .processingEstablishment {
                try session.transition(to: .processingEstablishment)
                delegate?.orchestrator(didUpdateState: session.currentState)
            }
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func didReceive(_ messageData: Data) {
        guard let session = getSession() else { return }
        do {
            // Sequencing violation in awaitingUserConsent or processingResponse
            guard session.currentState == .processingEstablishment else {
                // Ignore messages if already terminating or in terminal state
                guard session.currentState.kind != .terminatingSession,
                      session.currentState.kind != .success,
                      session.currentState.kind != .failed,
                      session.currentState.kind != .cancelled else { return }
                
                // Status-only SessionData triggers peer termination handling
                if let sessionData = try? SessionData(fromCBOR: messageData), sessionData.data == nil {
                    handlePeerTermination(sessionData: sessionData)
                    return
                }
                initiateTermination(then: .failed(.sequencingViolation("Received message with data while in \(session.currentState.kind.rawValue) state")))
                return
            }
            
            let processed = try cryptoService?.processSessionEstablishment(incoming: messageData, in: session)

            if let processed {
                Task {
                    await self.authenticateAndHandleOutcome(processed, in: session)
                }
            }
        } catch CryptoServiceError.sessionDataReceived(let sessionData) {
            if sessionData.data == nil {
                // Status-only SessionData: peer termination signal
                handlePeerTermination(sessionData: sessionData)
            } else {
                // SessionData with data when SessionEstablishment expected: sequencing violation
                initiateTermination(then: .failed(.sequencingViolation("Received SessionData with data payload when SessionEstablishment was expected")))
            }
        } catch let error as SessionEstablishmentError {
            // SessionEstablishment CBOR decode failure
            initiateTermination(then: .failed(.generic(error.errorDescription ?? "Unknown error")))
        } catch is DecryptionError {
            // SessionEstablishment decryption failure
            initiateTermination(then: .failed(.generic("Decryption failed")))
        } catch let error as CryptoServiceError {
            // Crypto key agreement or context failure during SessionEstablishment processing
            initiateTermination(then: .failed(.generic(error.errorDescription ?? "Unknown error")))
        } catch {
            initiateTermination(
                then: .failed(.generic(error.localizedDescription))
            )
        }
    }

    /// Authenticates the decrypted request with Reader Authentication, then
    /// routes the outcome into the existing flow.
    ///
    /// - `.authenticated` stores the selected request on the session and derives
    ///   the credential request from it alone.
    /// - `.unfulfillable` follows the existing empty-response path without any
    ///   credential access.
    /// - A `ReaderAuthenticationFailure` follows the reader-policy-violation path;
    ///   `malformedDeviceRequest` follows the invalid-request path. Neither
    ///   touches the `CredentialProvider`.
    private func authenticateAndHandleOutcome(
        _ processed: ProcessedSessionEstablishment,
        in session: HolderSessionProtocol
    ) async {
        // Legacy/empty-trust routing. When no trusted Reader
        // certificates were supplied, Reader Authentication cannot run, so admit
        // the request synthetically — skipping both Reader Authentication and
        // CoseVerification — and route it through the same continuation the
        // authenticated path uses.
        guard !trustedReaderCertificates.isEmpty else {
            Logger.log("Reader certificate list is empty — admitting request synthetically (skipping Reader Authentication)")
            await admitSynthetically(processed, in: session)
            return
        }

        Logger.log("Reader certificate list is non-empty — running Reader Authentication")

        let verificationRequest = ReaderAuthenticationVerificationRequest(
            encodedDeviceRequest: processed.decryptedRequestBytes,
            untaggedSessionTranscriptBytes: processed.untaggedSessionTranscriptBytes,
            trustedReaderCertificates: trustedReaderCertificates,
            supportedDocumentTypes: supportedDocumentTypes
        )

        let outcome: ReaderAuthenticationOutcome
        do {
            outcome = try await readerAuthenticator.authenticateDeviceRequest(verificationRequest)
        } catch let failure as ReaderAuthenticationFailure {
            handleReaderAuthenticationFailure(failure, in: session)
            return
        } catch {
            guard isSessionCurrent(session) else { return }
            initiateTermination(then: .failed(.generic(error.localizedDescription)))
            return
        }

        // Session may have been torn down or transitioned while awaiting authentication.
        guard isSessionCurrent(session) else { return }

        switch outcome {
        case .authenticated(let authenticatedRequest):
            await continueWithAuthenticatedRequest(authenticatedRequest, in: session)

        case .unfulfillable:
            // No supported candidate: follow the existing empty-response path
            // without any credential access.
            initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .emptyResponse))
        }
    }

    /// Reader Authentication and CoseVerification are deliberately skipped. The
    /// decrypted `DeviceRequest` is decoded and the first supported `DocRequest`
    /// in wire order is selected. A supported request is wrapped in a synthetic
    /// ``AuthenticatedReaderRequest`` carrying the fixed SDK-owned privacy-policy
    /// URL, then routed through the same continuation the authenticated path
    /// uses. When no supported request exists, the existing unfulfillable path
    /// is followed and the Holder continuation receives nothing.
    private func admitSynthetically(
        _ processed: ProcessedSessionEstablishment,
        in session: HolderSessionProtocol
    ) async {
        let decoded: DecodedDeviceRequest
        do {
            decoded = try DecodedDeviceRequest(encodedCBOR: processed.decryptedRequestBytes)
        } catch {
            // A request we cannot decode is an invalid device request — the same
            // termination the authenticated path uses for a malformed request.
            initiateTermination(
                deviceResponseStatus: .cborDecodingError,
                then: .failed(.invalidDeviceRequest)
            )
            return
        }

        // Select the first supported DocRequest in wire order. Requested elements
        // and namespaces are not inspected here.
        guard let selected = decoded.documents.first(where: {
            supportedDocumentTypes.contains($0.itemsRequest.docType)
        }) else {
            // No supported request: existing unfulfillable path, no credential access.
            initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .emptyResponse))
            return
        }

        // The synthetic privacy-policy URL is scoped to this EX1 empty-trust path
        // only. In the main flow the privacy-policy URL is supplied by the
        // verified reader certificate, so this must not live on the orchestrator.
        // It is injected by the Consumer (sourced from the app's configuration),
        // so there is no hardcoded URI in the SDK.
        guard let privacyPolicyURL = syntheticPrivacyPolicyURL else {
            // No synthetic URL was configured by the Consumer; fail closed rather
            // than fabricate one.
            initiateTermination(then: .failed(.generic("Missing synthetic privacy-policy URL.")))
            return
        }

        let syntheticRequest = AuthenticatedReaderRequest(
            docRequest: selected,
            privacyPolicyURL: privacyPolicyURL,
            // Empty-trust path: no verified reader certificate, so no organization
            // name. Use an empty value rather than nil so the shared continuation
            // builds consent instead of treating this expected state as an error.
            organizationName: "Example Organisation Name"
        )

        await continueWithAuthenticatedRequest(syntheticRequest, in: session)
    }

    /// The Holder continuation shared by the authenticated path and the EX1
    /// synthetic-admission path: resolves and stores the response document type,
    /// then proceeds to credential validation and filtering.
    private func continueWithAuthenticatedRequest(
        _ authenticatedRequest: AuthenticatedReaderRequest,
        in session: HolderSessionProtocol
    ) async {
        guard let docType = DocType(rawValue: authenticatedRequest.docRequest.itemsRequest.docType) else {
            initiateTermination(then: .failed(.generic("Unsupported document type.")))
            return
        }
        do {
            try session.setResponseDocType(docType)
        } catch {
            initiateTermination(then: .failed(.generic(error.localizedDescription)))
            return
        }
        await validateCredential(for: authenticatedRequest, in: session)
    }

    /// Maps a Reader Authentication failure to the existing termination paths.
    /// A malformed request is an invalid device request; any other failure is a
    /// reader-policy violation. The `CredentialProvider` is never called.
    private func handleReaderAuthenticationFailure(
        _ failure: ReaderAuthenticationFailure,
        in session: HolderSessionProtocol
    ) {
        guard isSessionCurrent(session) else { return }

        switch failure {
        case .malformedDeviceRequest:
            initiateTermination(
                deviceResponseStatus: .cborDecodingError,
                then: .failed(.invalidDeviceRequest)
            )
        default:
            initiateTermination(
                deviceResponseStatus: .generalError,
                then: .failed(.policyViolation(reason: "\(failure)"))
            )
        }
    }

    /// Whether the captured session is still the active one and remains in
    /// `processingEstablishment` — guards every resumption after an `await`.
    private func isSessionCurrent(_ session: HolderSessionProtocol) -> Bool {
        self.session != nil && session.currentState == .processingEstablishment
    }

    private func validateCredential(for authenticatedRequest: AuthenticatedReaderRequest, in session: HolderSessionProtocol) async {
        do {
            try await credentialRequestHandler.requestAndValidateCredential(for: authenticatedRequest.docRequest, in: session)
            
            // Session may have been torn down or transitioned while awaiting credential validation
            guard isSessionCurrent(session) else { return }
            
            filterIssuerSigned(for: authenticatedRequest, in: session)
        } catch let error as CredentialRequestError {
            guard isSessionCurrent(session) else { return }
            handleTermination(with: error, deviceResponseStatus: .ok)
        } catch {
            guard isSessionCurrent(session) else { return }
            handleTermination(with: error)
        }
    }
    
    private func filterIssuerSigned(for authenticatedRequest: AuthenticatedReaderRequest, in session: HolderSessionProtocol) {
        do {
            let filterResult = try credentialRequestHandler.filterIssuerSigned(for: authenticatedRequest.docRequest, in: session)
            
            guard let presentation = makeConsentPresentation(from: filterResult, authenticatedRequest: authenticatedRequest) else {
                return
            }
            
            try session.transition(to: .awaitingUserConsent(presentation))
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch let error as IssuerSignedFilterError {
            Logger.log(error.localizedDescription, level: .error)
            switch error {
            case .noMatchingNameSpaces, .noMatchingAttributes:
                initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .emptyResponse))
            case .exceededAgeOverLimit:
                initiateTermination(deviceResponseStatus: .generalError, then: .failed(.invalidDeviceRequest))
            case .portraitNotRequested:
                initiateTermination(deviceResponseStatus: .generalError, then: .failed(.policyViolation(reason: "portraitNotRequested")))
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func makeConsentPresentation(
        from filterResult: FilterResult,
        authenticatedRequest: AuthenticatedReaderRequest
    ) -> ConsentPresentation? {
        guard let organizationName = authenticatedRequest.organizationName else {
            initiateTermination(then: .failed(.generic("Organization name not found in authenticated request.")))
            return nil
        }
        
        let attributes: [ConsentAttribute] = filterResult.retention.flatMap { nameSpace, values in
            values.map { identifier, intentToRetain in
                ConsentAttribute(
                    namespace: nameSpace,
                    displayLabel: identifier,
                    intentToRetain: intentToRetain
                )
            }
        }
        
        // TODO: DCMAW-23705 - Source actual documentIconImage SVG
        let documentType = DocumentType(displayLabel: filterResult.docType, documentIcon: UIImage())
        
        return ConsentPresentation(
            dvsName: organizationName,
            documentType: documentType,
            attributes: attributes,
            privacyPolicyURL: authenticatedRequest.privacyPolicyURL
        )
    }
    
    public func userDidTapApprove() {
        guard let session = getSession(),
              session.currentState.kind == .awaitingUserConsent else { return }
        
        Task {
            await prepareDeviceSignedResponse()
        }
    }
    
    func prepareDeviceSignedResponse() async {
        guard let session = getSession() else { return }

        do {
            try cryptoService?.constructSigStructure(in: session)
            try await credentialRequestHandler.signSigStructure(in: session)
        } catch let error as CredentialSigningError {
            switch error {
            case .recoverable:
                Logger.log("Local authentication cancelled — remaining on consent screen")
                return
            case .unrecoverable:
                guard self.session != nil,
                      session.currentState.kind == .awaitingUserConsent else { return }
                initiateTermination(deviceResponseStatus: .ok, then: .failed(.generic("Credential signing failed: unrecoverable error from CredentialProvider")))
                return
            }
        } catch {
            guard self.session != nil,
                  session.currentState.kind == .awaitingUserConsent else { return }
            initiateTermination(then: .failed(.generic("Failed to prepare device signature: \(error.localizedDescription)")))
            return
        }

        guard self.session != nil,
              session.currentState.kind == .awaitingUserConsent else { return }

        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            try cryptoService?.generateDeviceSigned(in: session)
            assembleAndEncryptResponse()
        } catch {
            initiateTermination(then: .failed(.generic(error.localizedDescription)))
        }
    }
    
    func assembleAndEncryptResponse() {
        guard let session = getSession() else { return }
        guard let docType = session.docType,
        let issuerSigned = session.issuerSigned,
        let deviceSigned = session.deviceSigned else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return
        }
        let document = Document(
            docType: docType,
            issuerSigned: issuerSigned,
            deviceSigned: deviceSigned
        )
        do {
            let deviceResponse = DeviceResponse(documents: [document], status: .ok)
            let encryptedData = try cryptoService?.encryptDeviceResponse(deviceResponse, in: session)
            try session.setDeviceResponse(deviceResponse)
            
            if let encryptedData {
                let sessionData = SessionData(data: encryptedData)
                encodeAndSend(sessionData) {
                    /// Callback to trigger transition to `.awaitingVerifierResolution` state when response sent successfully
                    self.transitionToAwaitingVerifierResolution()
                }
            }
        } catch {
            handleTermination(with: error)
        }
    }
    
    private func transitionToAwaitingVerifierResolution() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .awaitingVerifierResolution)
            delegate?.orchestrator(didUpdateState: session.currentState)
        } catch {
            try? session.transition(to: .failed(.incorrectSessionState(session.currentState.kind.rawValue)))
            delegate?.orchestrator(didUpdateState: session.currentState)
        }
    }
    
    private func transitionToTerminalState(_ terminalState: HolderSessionState) {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: terminalState)
            delegate?.orchestrator(didUpdateState: session.currentState)

        } catch {
            try? session.transition(to: .failed(.incorrectSessionState(session.currentState.kind.rawValue)))
            delegate?.orchestrator(didUpdateState: session.currentState)
        }
    }

    private func encodeAndSend(_ sessionData: SessionData, with error: Error? = nil, completion: (() -> Void)? = nil) {
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        sendCompletion = completion
        bluetoothTransport?.sendSessionData(encodedBytes)
        
        if let error {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    // MARK: - Connection Loss (GATT End / raw BLE disconnect)

    /// Handles both GATT `End` and raw BLE disconnects (unsubscribe, out of range, BT toggled off, etc.)
    /// Behaviour is determined by the current session state:
    /// - Fatal (pre-response): `.failed(.transportError)` + BLE disconnected screen
    /// - Non-fatal (post-response): `.success(.responseSent)` + "details shared" screen stays
    /// - Already terminal: no-op
    /// - During ordered teardown: suppress inbound signal
    private func handleConnectionLoss() {
        guard let session else {
            tearDownSession(andNotify: false)
            return
        }

        switch session.currentState.kind {
        // During ordered teardown - suppress
        case .terminatingSession:
            break

        // Already terminal - no-op
        case .success, .failed, .cancelled:
            break

        // Post-response — success
        case .awaitingVerifierResolution:
            sendCompletion = nil
            transitionToTerminalState(.success(reason: .responseSent))
            tearDownSession(andNotify: false)

        // Pre-response / actively processing — failed
        case .processingEstablishment, .awaitingUserConsent, .processingResponse:
            sendCompletion = nil
            transitionToTerminalState(.failed(.transportError))
            tearDownSession(andNotify: false)

        // Pre-connection states - cancel journey
        default:
            sendCompletion = nil
            transitionToCancel()
            tearDownSession(andNotify: false)
        }
    }

    // MARK: - Peer Termination (Inbound SessionData with status, no data)
    
    /// Handles an incoming status-only SessionData from the Verifier indicating session termination.
    /// No outbound signal (no GATT End, no termination message) is sent.
    /// - In `awaitingVerifierResolution`: status 20 == success, non-20 == failed (screen stays on "details shared").
    /// - In pre-response states: any status == failed with generic error screen.
    private func handlePeerTermination(sessionData: SessionData) {
        guard let session = getSession() else { return }
        
        switch session.currentState.kind {
        case .awaitingVerifierResolution:
            if sessionData.status == .sessionTermination {
                transitionToTerminalState(.success(reason: .responseSent))
            } else {
                transitionToTerminalState(.failed(.peerTermination))
            }
            tearDownSession(andNotify: false)
            
        case .processingEstablishment, .awaitingUserConsent, .processingResponse:
            transitionToTerminalState(.failed(.peerTermination))
            tearDownSession(andNotify: false)
            
        default:
            break
        }
    }
    
    // MARK: - Initiating Termination (Ordered Teardown)
    
    /// Initiates programmatic termination
    /// 1. CryptoService builds SessionData(status: 20) with optional encrypted payload
    /// 2. Orchestrator sends the message via BluetoothTransport
    /// 3. Wait for send-completion + 500ms  buffer
    /// 4. Send GATT End
    /// 5. Transition to terminal state
    /// 6. Destroy session
    private func initiateTermination(
        deviceResponseStatus: DeviceResponseStatus? = nil,
        then terminalState: HolderSessionState
    ) {
        guard let session = getSession() else { return }
        do {
            
            var encryptedPayload: Data?
            if let deviceResponseStatus {
                let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
                encryptedPayload = try? cryptoService?.encryptDeviceResponse(errorResponse, in: session)
                try session.setDeviceResponse(errorResponse)
            }
            
            try session.transition(to: .terminatingSession)
            sendTerminationMessage(encryptedPayload: encryptedPayload) {
                self.performDelayedGATTEndAndTeardown(then: terminalState)
            }
        } catch {
            sendTerminationMessage()
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }

    // MARK: - Interruption & Cancellation

    /// Sends a bare termination message (status: 20, no payload) and notifies delegate of failure.
    /// Used for error paths where the full delayed GATT End teardown is not required.
    private func handleTermination(with error: Error?, deviceResponseStatus: DeviceResponseStatus? = nil) {
        guard let session = getSession() else { return }
        
        var encryptedPayload: Data?
        if let deviceResponseStatus {
            let errorResponse = DeviceResponse(documents: nil, status: deviceResponseStatus)
            encryptedPayload = try? cryptoService?.encryptDeviceResponse(errorResponse, in: session)
        }
        
        sendTerminationMessage(encryptedPayload: encryptedPayload)
        
        if let error {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func sendTerminationMessage(encryptedPayload: Data? = nil, completion: (() -> Void)? = nil) {
        guard let session = getSession() else { return }
        let terminationBytes = cryptoService?.buildTerminationMessage(encryptedPayload: encryptedPayload, in: session)
        
        if let terminationBytes {
            sendCompletion = completion
            bluetoothTransport?.sendSessionData(terminationBytes)
        }
        Logger.log("Termination message sent")
    }
    
    public func userDidTapDeny() {
        guard let session = getSession() else { return }
        do {
            try session.transition(to: .processingResponse)
            delegate?.orchestrator(didUpdateState: session.currentState)
            
            initiateTermination(deviceResponseStatus: .ok, then: .success(reason: .denialResponse))
        } catch {
            delegate?.orchestrator(didUpdateState: .failed(.generic(error.localizedDescription)))
        }
    }
    
    private func performDelayedGATTEndAndTeardown(then terminalState: HolderSessionState) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.gattEndDelay))
            
            self.bluetoothTransport?.sendGattEnd()
            self.transitionToTerminalState(terminalState)
            self.tearDownSession(andNotify: false)
        }
    }
    
    public func userDidTapCancel() {
        guard let session else { return }

        switch session.currentState.kind {
        // Cancel with prompt — active BLE connection, user must confirm
        case .processingEstablishment, .awaitingUserConsent:
            delegate?.orchestratorDidRequestCancelConfirmation()

        // Cancel without prompt — no BLE connection or post-consent
        case .notStarted, .preflight, .readyToPresent, .presentingEngagement,
             .processingResponse, .awaitingVerifierResolution:
            transitionToCancel()
            tearDownSession(andNotify: false)

        // Cannot be cancelled — already in a terminal or terminating state
        case .terminatingSession, .success, .failed, .cancelled, .expired:
            break
        }
    }

    public func userDidConfirmCancel() {
        guard session != nil else { return }
        // User confirmed cancellation - send GATT End only, no SessionData
        transitionToCancel()
        tearDownSession(andNotify: true)
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

    // MARK: - QR Code Generation Failure

    /// Called by the UI layer when it fails to render the engagement QR code from the
    /// payload supplied in `.presentingEngagement`/`.readyToPresent`. There is no BLE
    /// connection at this point, so no termination message or GATT End is required —
    /// we transition to a terminal `.failed` state (routing the UI to the error screen)
    /// and tear down the session. Guarded to pre-connection states so a late or duplicate
    /// callback cannot destroy an in-progress transaction.
    public func qrCodeGenerationDidFail() {
        guard let session else { return }

        switch session.currentState.kind {
        case .readyToPresent, .presentingEngagement:
            Logger.log("QR code generation failed — tearing down session", level: .error)
            transitionToTerminalState(.failed(.generic("Something went wrong. Try again later.")))
            tearDownSession(andNotify: false)
        default:
            break
        }
    }
    
    // MARK: - Inactivity Timeout
    
    private func startInactivityTimer() {
        if inactivityTimer == nil {
            inactivityTimer = InactivityTimer { [weak self] in
                self?.handleInactivityTimeout()
            }
        }
        inactivityTimer?.start()
    }
    
    func handleInactivityTimeout() {
        guard let session,
              session.currentState.isActiveState else { return }
        
        Logger.log("Inactivity timeout fired — sending GATT End From Holder")
        transitionToCancel()
        tearDownSession(andNotify: true)
    }
    
    // MARK: - Engagement Refresh
    
    private func startEngagementRefreshTimer() {
        if engagementRefreshTimer == nil {
            engagementRefreshTimer = InactivityTimer(duration: .seconds(5)) { [weak self] in
                self?.handleEngagementRefresh()
            }
        }
        engagementRefreshTimer?.start()
    }
    
    func handleEngagementRefresh() {
        // Only refresh while still presenting the QR code. Once a verifier connects,
        // the state moves beyond .presentingEngagement and the refresh must not fire,
        // otherwise it would destroy an in-progress transaction.
        guard let session,
              session.currentState.kind == .presentingEngagement else { return }
        
        Logger.log("Engagement refresh fired — regenerating QR code")
        engagementRefreshTimer?.stop()
        engagementRefreshTimer = nil
        tearDownSession(andNotify: false)
        startPresentation()
    }
    
    private func tearDownSession(andNotify: Bool) {
        inactivityTimer?.stop()
        inactivityTimer = nil
        engagementRefreshTimer?.stop()
        engagementRefreshTimer = nil
        session?.connectionHandle?.notify = andNotify
        bluetoothTransport = nil
        session = nil
        cryptoService = nil
        prerequisiteGate = nil
        // Release the captured Reader trust snapshot when the Session ends.
        // A later journey supplies and captures a fresh snapshot.
        trustedReaderCertificates = []
        Logger.log("Holder Presentation Session ended")
    }
    
    public func resolve(_ missingPrerequisite: MissingPrerequisite) {
        prerequisiteGate?.triggerResolution(for: missingPrerequisite)
    }
    
    private func getSession() -> HolderSessionProtocol? {
        guard let session else {
            delegate?.orchestrator(didUpdateState: .failed(.generic("Session is not available.")))
            return nil
        }
        return session
    }
}

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        if case .peripheral(.connectionTerminated) = error {
            handleConnectionLoss()
        } else if case .peripheral(.notPoweredOn(.poweredOff)) = error {
            handleConnectionLoss()
        } else if case .peripheral(.exceededMaxBufferSize) = error {
            transitionToTerminalState(.failed(.generic(error.localizedDescription)))
        } else {
            transitionToTerminalState(.failed(.transportError))
        }
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        presentQRCode()
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        if session?.currentState != .processingEstablishment {
            Logger.log("Timer started for Holder")
            startInactivityTimer()
        }
        connectionDidConnect()
    }

    public func bluetoothTransportDidDiscover() {
        // This delegate function is not used by the HolderOrchestrator
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        inactivityTimer?.reset()
        didReceive(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        Logger.log("BLE session terminated via GATT End command")
        handleConnectionLoss()
    }
    
    public func bluetoothTransportDidFinishSending() {
        inactivityTimer?.reset()
        let completion = sendCompletion
        sendCompletion = nil
        completion?()
    }
    
    public func bluetoothTransportDidStartSession() {
        // This delegate function is not used by the HolderOrchestrator
    }
}
// swiftlint:enable file_length
