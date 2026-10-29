import ExchangeFormat
import ReaderAuthentication
import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import SwiftCBOR
import Testing
import UIKit
import X509

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@MainActor
@Suite("HolderOrchestrator Tests", .serialized)
struct HolderOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var mockBluetoothTransport = MockBluetoothTransport()
    var mockCryptoService = MockCryptoService()
    var mockCredentialRequestHandler = MockCredentialRequestHandler()
    var mockInactivityTimer = MockInactivityTimer()
    var mockEngagementHideTimer = MockInactivityTimer()
    var mockEngagementExpiryTimer = MockInactivityTimer()
    var mockReaderAuthenticator = MockReaderAuthenticating()
    var sut: HolderOrchestrator

    init() {
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            credentialRequestHandler: mockCredentialRequestHandler,
            readerAuthenticator: mockReaderAuthenticator
        )
    }

    private func setupOrchestrator(
        prerequisiteGate: PrerequisiteGateProtocol? = nil,
        bluetoothTransport: BluetoothTransportProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil,
        credentialRequestHandler: CredentialRequestHandlerProtocol? = nil,
        inactivityTimer: InactivityTimerProtocol? = nil,
        engagementHideTimer: InactivityTimerProtocol? = nil,
        engagementExpiryTimer: InactivityTimerProtocol? = nil,
        readerAuthenticator: ReaderAuthenticating? = nil,
        trustedReaderCertificates: [Certificate]? = nil
    ) -> HolderOrchestrator {
        // Default to a non-empty trusted-certificate list so the Reader
        // Authentication path runs. The empty-trust/synthetic path (EX1) is
        // exercised only by tests that pass `trustedReaderCertificates: []`.
        let trustedCertificates = trustedReaderCertificates
            ?? ((try? TestCertificate.issuer).map { [$0] } ?? [])
        return HolderOrchestrator(
            prerequisiteGate: prerequisiteGate ?? mockPrerequisiteGate,
            bluetoothTransport: bluetoothTransport ?? mockBluetoothTransport,
            cryptoService: cryptoService ?? mockCryptoService,
            credentialRequestHandler: credentialRequestHandler ?? mockCredentialRequestHandler,
            inactivityTimer: inactivityTimer ?? mockInactivityTimer,
            engagementTimers: EngagementTimers(
                hide: engagementHideTimer ?? mockEngagementHideTimer,
                expiry: engagementExpiryTimer ?? mockEngagementExpiryTimer
            ),
            readerAuthenticator: readerAuthenticator ?? mockReaderAuthenticator,
            trustedReaderCertificates: trustedCertificates,
            supportedDocumentTypes: HolderOrchestrator.productSupportedDocumentTypes,
            // The synthetic (EX1 empty-trust) privacy-policy URL is injected by the
            // Consumer in production (via Info.plist). Tests inject it directly so
            // AC1 can assert the exact URL without a hardcoded literal in the SDK.
            syntheticPrivacyPolicyURL: URL(string: "https://www.gov.uk/")
        )
    }

    private func makeDocRequest(
        nameSpaces: [String: [String: Bool]] = ["org.iso.18013.5.1": ["family_name": false, "portrait": false]]
    ) -> RequestedDocument {
        RequestedDocumentFixtures.make(
            docType: "org.iso.18013.5.1.mDL",
            nameSpaces: nameSpaces
        )
    }

    private func makeAuthenticatedRequest(
        _ docRequest: RequestedDocument? = nil
    ) -> AuthenticatedReaderRequest {
        AuthenticatedReaderRequest(
            docRequest: docRequest ?? makeDocRequest(),
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!,
            organizationName: "GDS"
        )
    }

    /// The consent payload the mock credential handler returns, and therefore the
    /// payload the session carries once it reaches `.awaitingUserConsent`.
    private func makeFilterResult() -> FilterResult {
        mockCredentialRequestHandler.stubbedFilterResult
    }

    /// The `ConsentPresentation` the orchestrator builds from the stubbed filter
    /// result and authenticated request. Mirrors `makeConsentPresentation` in the
    /// orchestrator so tests can assert the resulting state.
    ///
    /// Note: `DocumentType.documentIcon` is a placeholder `UIImage()` which is not
    /// value-equal across instances, so whole-state equality is unreliable. Compare
    /// individual fields via `extractConsentPresentation` instead.
    private func makeConsentPresentation(
        from filterResult: FilterResult? = nil,
        authenticatedRequest: AuthenticatedReaderRequest? = nil
    ) -> ConsentPresentation {
        let result = filterResult ?? makeFilterResult()
        let request = authenticatedRequest ?? makeAuthenticatedRequest()
        let attributes: [ConsentAttribute] = result.retention.flatMap { nameSpace, values in
            values.map { identifier, intentToRetain in
                ConsentAttribute(
                    namespace: nameSpace,
                    displayLabel: identifier,
                    intentToRetain: intentToRetain
                )
            }
        }
        return ConsentPresentation(
            dvsName: request.organizationName ?? "",
            documentType: DocumentType(displayLabel: result.docType, documentIcon: UIImage()),
            attributes: attributes,
            privacyPolicyURL: request.privacyPolicyURL
        )
    }

    /// Extracts the `ConsentPresentation` from a session state when in
    /// `.awaitingUserConsent`, so tests can assert on fields that are value-equal
    /// (everything except the placeholder `documentIcon`).
    private func extractConsentPresentation(
        from state: HolderSessionState?
    ) -> ConsentPresentation? {
        guard case let .awaitingUserConsent(presentation) = state else { return nil }
        return presentation
    }

    // MARK: - EX1 fixtures

    /// Encodes a minimal, decodable `DeviceRequest` whose `docRequests` carry the
    /// given document types in order, so synthetic-admission tests can exercise
    /// first-supported selection in wire order. Each `itemsRequest` is wrapped as
    /// `#6.24(bstr .cbor ItemsRequest)` and has no `readerAuth` (the synthetic
    /// path never inspects it).
    private func encodedDeviceRequest(docTypes: [String]) -> Data {
        let docRequests: [CBOR] = docTypes.map { docType in
            let itemsRequest: CBOR = .map([
                .utf8String("docType"): .utf8String(docType),
                .utf8String("nameSpaces"): .map([
                    .utf8String("org.iso.18013.5.1"): .map([
                        .utf8String("family_name"): .boolean(false),
                        .utf8String("portrait"): .boolean(false)
                    ])
                ])
            ])
            let tag24 = CBOR.tagged(.encodedCBORDataItem, .byteString(itemsRequest.encode()))
            return .map([.utf8String("itemsRequest"): tag24])
        }
        let deviceRequest: CBOR = .map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("docRequests"): .array(docRequests)
        ])
        return Data(deviceRequest.encode())
    }
    
    @Test("startTransaction creates a new HolderSession object")
    func startPresentationCreatesHolderSession() {
        // Given
        #expect(sut.session == nil)
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(sut.session != nil)
    }
    
    @Test("userDidTapCancel sets the session & all packages to nil")
    mutating func userDidTapCancelSetsSessionToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()

        #expect(sut.session != nil)
        #expect(sut.prerequisiteGate != nil)
        #expect(sut.cryptoService != nil)
        #expect(sut.bluetoothTransport != nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == false)
        
        // When
        sut.userDidTapCancel()
        
        // Then
        #expect(sut.session == nil)
        #expect(sut.prerequisiteGate == nil)
        #expect(sut.cryptoService == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }
    
    @Test("startTransaction successfully transitions to .readyToPresent when capabilities are allowed")
    func startPresentationProceedsToReadyToPresent() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(sut.session?.currentState == .readyToPresent)
    }
    
    @Test("startTransaction successfully transitions to .preflight when capabilities are not allowed")
    func startPresentationProceedsToPreflight() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationNotDetermined)]
        
        // When
        sut.startTransaction()
        
        // Then
        let expectedPresentation = ReadinessPresentation(
            missingPrerequisites: mockPrerequisiteGate.missingPrerequisitesToReturn,
            cancelRequiresConfirmation: false
        )
        #expect(sut.session?.currentState == .preflight(expectedPresentation))
    }
    
    @Test("resolve triggers triggerResolutionfunc on PrerequisiteGate")
    func resolveTriggersPRGateFunc() throws {
        // Given
        _ = try #require(sut.prerequisiteGate)
        #expect(mockPrerequisiteGate.didCallTriggerResolution == false)
        
        // When
        sut.resolve(MissingPrerequisite.bluetooth(.authorizationNotDetermined))
        
        // Then
        #expect(mockPrerequisiteGate.didCallTriggerResolution == true)
    }
    
    @Test("prepareEngagement transitions to .presentingEngagement state")
    mutating func didStartAdvertisingTransitionsToPresentingEngagement() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        // When
        /// With bluetoothTransport mocked, startTransaction will successfully proceed to prepareEngagement
        sut.startTransaction()
        
        // Then
        let qrPayload = try #require(sut.session?.qrPayload)
        let engagementPresentation = EngagementPresentation(qrPayload: qrPayload, cancelRequiresConfirmation: false)
        #expect(sut.session?.currentState == .presentingEngagement(engagementPresentation))
    }
    
    @Test("prepareEngagement renders error when session is nil")
    func prepareEngagementRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.prepareEngagement()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("prepareEngagement renders error when cryptoContext is nil")
    mutating func prepareEngagementRendersErrorContextNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.forceFailureWithInvalidData = true
        
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session engagement failed to prepare correctly.")))
    }
    
    @Test("presentQRCode renders error when qrCode on session is nil")
    mutating func presentQRCodeWhenNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        /// Public delegate function that calls private presentQRCode function
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("QR Code failed to generate.")))
    }
    
    @Test("connectionDidConnect transitions to .processingEstablishment state")
    mutating func connectionDidConnectTransitionsToProcessingEstablishment() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        // When
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(sut.session?.currentState == .processingEstablishment)
    }

    @Test("test bluetoothTransportDidFail when processingEstablishment transitions session to failed")
    mutating func test_bluetoothTransportDidFail_whenProcessingEstablishment_transitionsSessionToFailed() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidFail(with: .central(.exceededMaxBufferSize(currentSize: 2048, maxSize: 1024)))

        // Then
        #expect(sut.session?.currentState.kind == .failed)
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    @Test("connectionDidConnect renders error when session is nil")
    func connectionDidConnectRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test(".didReceive calls cryptoService.processSessionEstablishment")
    mutating func didReceiveCallsCryptoServiceFunction() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        #expect(mockCryptoService.didCallProcessSessionEstablishment == false)
        #expect(mockCryptoService.incomingBytes == nil)
        #expect(mockCryptoService.passedSession == nil)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockCryptoService.didCallProcessSessionEstablishment == true)
        #expect(mockCryptoService.incomingBytes == data)
        // Checking the session matches by comparing the cryptoContext.serviceUUID
        #expect(mockCryptoService.passedSession?.cryptoContext?.serviceUUID == sut.session?.cryptoContext?.serviceUUID)
    }
    
    @Test(".didReceive transitions to requestReceived and renders state")
    mutating func didReceiveTransitionsToRequestReceivedAndRendersState() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let docRequest = makeDocRequest()
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest(docRequest))
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { sut.session?.currentState.kind == .awaitingUserConsent }
        
        // Then
        let presentation = try #require(extractConsentPresentation(from: sut.session?.currentState))
        #expect(presentation.dvsName == "GDS")
        #expect(presentation.documentType.displayLabel == "org.iso.18013.5.1.mDL")
        #expect(presentation.attributes == makeConsentPresentation().attributes)
        #expect(presentation.privacyPolicyURL == URL(string: "https://example.gov.uk/privacy")!)
        #expect(mockDelegate.stateToRender?.kind == .awaitingUserConsent)
    }

    // MARK: - EX1 (DCMAW-23450): Synthetic admission on the legacy/empty-trust path

    @Test("Empty trust: admits synthetically without calling Reader Authentication (bypass)")
    mutating func emptyTrustBypassesReaderAuthentication() async throws {
        // Given — orchestrator built with an empty trusted-certificate list.
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.stubbedDecryptedRequestBytes = encodedDeviceRequest(
            docTypes: ["org.iso.18013.5.1.mDL"]
        )
        sut = setupOrchestrator(trustedReaderCertificates: [])
        #expect(sut.trustedReaderCertificates.isEmpty)

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { sut.session?.currentState.kind == .awaitingUserConsent }

        // Then — Reader Authentication (and therefore CoseVerification) was never invoked.
        #expect(mockReaderAuthenticator.didCallAuthenticate == false)
    }

    @Test("Empty trust: selects the first supported DocRequest and uses the synthetic URL (AC1)")
    mutating func emptyTrustSelectsFirstSupportedWithSyntheticURL() async throws {
        // Given — unsupported request A followed by mDL request B, in wire order.
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.stubbedDecryptedRequestBytes = encodedDeviceRequest(
            docTypes: ["org.iso.18013.5.1.unsupported", "org.iso.18013.5.1.mDL"]
        )
        sut = setupOrchestrator(trustedReaderCertificates: [])

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { sut.session?.currentState.kind == .awaitingUserConsent }

        // Then — the continuation received request B (the first supported one)…
        let selected = try #require(mockCredentialRequestHandler.filteredDocRequest)
        #expect(selected.itemsRequest.docType == "org.iso.18013.5.1.mDL")

        // …and the consent presentation carries the exact synthetic URL.
        let presentation = try #require(extractConsentPresentation(from: sut.session?.currentState))
        #expect(presentation.privacyPolicyURL == URL(string: "https://www.gov.uk/")!)
        #expect(mockReaderAuthenticator.didCallAuthenticate == false)
    }

    @Test("Empty trust: no supported DocRequest follows the unfulfillable path (AC2)")
    mutating func emptyTrustNoSupportedRequestIsUnfulfillable() async throws {
        // Given — a request with no supported document type.
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.stubbedDecryptedRequestBytes = encodedDeviceRequest(
            docTypes: ["org.iso.18013.5.1.unsupported"]
        )
        sut = setupOrchestrator(trustedReaderCertificates: [])
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)

        // The unfulfillable path terminates the session; the terminal state is
        // delivered to the delegate before the session is torn down, so wait for
        // teardown and assert on the captured state rather than `sut.session`.
        await eventually { sut.session == nil }

        // Then — the current unfulfillable (empty-response) result, and the Holder
        // continuation never ran (no credential access, no Reader Authentication).
        #expect(mockDelegate.stateToRender == .success(reason: .emptyResponse))
        #expect(mockCredentialRequestHandler.filteredDocRequest == nil)
        #expect(mockCredentialRequestHandler.didCallFilterIssuerSigned == false)
        #expect(mockReaderAuthenticator.didCallAuthenticate == false)
    }
    
    @Test(".didReceive renders error when session is nil")
    func didReceiveRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("bluetoothTransportDidFail renders error")
    mutating func bluetoothTransportDidFailRendersError() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        let error = BluetoothTransportError.peripheral(.connectionTerminated)
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == .cancelled)
    }

    @Test("bluetoothTransportDidFail renders error")
    mutating func bluetoothTransportDidFailRendersAfterBluetoothDisconnectError() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        let error = BluetoothTransportError.peripheral(.notPoweredOn(.poweredOff))
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == .cancelled)
    }
    
    @Test("bluetoothTransportDidFail is ignored when session is nil")
    func bluetoothTransportDidFailIsIgnoredWhenSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        
        let error = BluetoothTransportError.peripheral(.connectionTerminated)
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == nil)
    }
    
    @Test("bluetoothTransportDidFail is ignored when session is in terminal state")
    mutating func bluetoothTransportDidFailIsIgnoredInTerminalState() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        try sut.session?.transition(to: .cancelled)
        mockDelegate.stateToRender = nil
        
        let error = BluetoothTransportError.peripheral(.connectionTerminated)
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == nil)
    }
    
    @Test("cancelPresentation sets all services to nil")
    mutating func cancelPresentationSetsServicesToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        // When
        /// With bluetoothTransport mocked, startTransaction will successfully proceed to prepareEngagement
        sut.startTransaction()
        #expect(sut.session != nil)
        #expect(sut.prerequisiteGate != nil)
        #expect(sut.bluetoothTransport != nil)
        #expect(sut.cryptoService != nil)
        
        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(sut.session == nil)
        #expect(sut.prerequisiteGate == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(sut.cryptoService == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }
    
    @Test("performPreflightChecks renders error when bluetooth auth is denied")
    func preflightChecksDeniedRendersError() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationDenied)]
        sut.delegate = mockDelegate
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.unrecoverablePrerequisite(MissingPrerequisite.bluetooth(.authorizationDenied))))
    }
    
    @Test("performPreflightChecks renders error when bluetooth auth is restricted")
    func preflightChecksRestrictedRendersError() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationRestricted)]
        sut.delegate = mockDelegate
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.unrecoverablePrerequisite(MissingPrerequisite.bluetooth(.authorizationRestricted))))
    }
    
    @Test("didReceive renders error when processSessionEstablishment throws")
    mutating func didReceiveRendersErrorWhenProcessingThrows() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        // Decoding no longer happens in processSessionEstablishment; drive the
        // failure directly through the crypto mock.
        mockCryptoService.proccessSessionEstablishmentShouldThrow = true
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        // When
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(Data([0x00]))
        
        // Then - termination message sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            mockBluetoothTransport.didCallSendGattEnd == true
        }

        // Then - full termination sequence completed
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    // MARK: - Sequencing violation in processingEstablishment (SessionData with data)
    @Test("Receiving SessionData with data in processingEstablishment triggers sequencing violation termination")
    mutating func didReceiveSessionDataWithDataTriggersSequencingViolation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        mockCryptoService.processSessionEstablishmentError = CryptoServiceError.sessionDataReceived(
            SessionData(data: Data([0x01, 0x02]), status: .sessionTermination)
        )

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)

        // Then - SessionData with status 20 sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender == .failed(.sequencingViolation("Received SessionData with data payload when SessionEstablishment was expected")))
    }

    @Test("Receiving status-only SessionData in processingEstablishment triggers peer termination")
    mutating func didReceiveStatusOnlySessionDataTriggersPeerTermination() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.processSessionEstablishmentError = CryptoServiceError.sessionDataReceived(
            SessionData(data: nil, status: .sessionTermination)
        )

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)

        // Then - peer termination: no outbound signal, session destroyed, failed state
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)
    }

    // MARK: - Sequencing violation in awaitingUserConsent or processingResponse
    @Test("Receiving non-status-only data in awaitingUserConsent triggers sequencing violation termination")
    mutating func didReceiveInAwaitingUserConsentTriggersSequencingViolation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingUserConsent
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When - receive non-status-only data
        sut.bluetoothTransportDidReceiveMessageData(Data([0x01, 0x02, 0x03]))

        // Then - SessionData with status 20 sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender == .failed(.sequencingViolation("Received message with data while in awaitingUserConsent state")))
    }

    @Test("Receiving non-status-only data in processingResponse triggers sequencing violation termination")
    mutating func didReceiveInProcessingResponseTriggersSequencingViolation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to processingResponse
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)

        // When - receive non-status-only data
        sut.bluetoothTransportDidReceiveMessageData(Data([0x01, 0x02, 0x03]))

        // Then - SessionData with status 20 sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender == .failed(.sequencingViolation("Received message with data while in processingResponse state")))
    }

    @Test("Status-only SessionData in awaitingUserConsent triggers peer termination")
    mutating func didReceiveStatusOnlySessionDataInAwaitingUserConsentTriggersPeerTermination() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingUserConsent
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // Construct status-only SessionData CBOR
        let statusOnlySessionData = SessionData(data: nil, status: .sessionTermination)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))

        // When - receive status-only SessionData
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - peer termination: no outbound signal, session destroyed, failed state
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)
    }

    // MARK: - Peer Termination

    @Test("Status 20 SessionData in awaitingVerifierResolution transitions to success(.responseSent)")
    mutating func peerTerminationStatus20InAwaitingVerifierResolution() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingVerifierResolution
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .awaitingVerifierResolution)

        // Construct status-only SessionData with status 20
        let statusOnlySessionData = SessionData(data: nil, status: .sessionTermination)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))

        // When
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - success, no outbound signal, session destroyed
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == .success(reason: .responseSent))
        #expect(sut.session == nil)
    }

    @Test("Non-20 status SessionData in awaitingVerifierResolution transitions to failed(.peerTermination)")
    mutating func peerTerminationNon20StatusInAwaitingVerifierResolution() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingVerifierResolution
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .awaitingVerifierResolution)

        // Construct status-only SessionData with non-20 status (e.g., sessionEncryption = 10)
        let statusOnlySessionData = SessionData(data: nil, status: .sessionEncryption)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))

        // When
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - failed, no outbound signal, session destroyed
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)
    }

    @Test("Status 20 SessionData followed by GATT End in awaitingVerifierResolution transitions to success")
    mutating func peerTerminationStatus20ThenGattEndInAwaitingVerifierResolution() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingVerifierResolution
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .awaitingVerifierResolution)

        // When - status 20 SessionData arrives first
        let statusOnlySessionData = SessionData(data: nil, status: .sessionTermination)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - session already torn down by peer termination
        #expect(mockDelegate.stateToRender == .success(reason: .responseSent))
        #expect(sut.session == nil)

        // When - GATT End arrives afterwards (no-op since session is nil)
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then - state unchanged, no crash
        #expect(mockDelegate.stateToRender == .success(reason: .responseSent))
    }

    @Test("Non-20 status SessionData followed by GATT End in awaitingVerifierResolution transitions to failed")
    mutating func peerTerminationNon20ThenGattEndInAwaitingVerifierResolution() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to awaitingVerifierResolution
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .awaitingVerifierResolution)

        // When - non-20 status SessionData arrives first
        let statusOnlySessionData = SessionData(data: nil, status: .cborDecoding)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - session torn down with failure
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)

        // When - GATT End arrives afterwards (no-op since session is nil)
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then - state unchanged, no crash
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
    }

    @Test("Status-only SessionData in processingResponse triggers peer termination")
    mutating func peerTerminationInProcessingResponse() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to processingResponse
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)

        // Construct status-only SessionData CBOR
        let statusOnlySessionData = SessionData(data: nil, status: .sessionTermination)
        let statusOnlyCBOR = Data(statusOnlySessionData.encode(options: CBOROptions()))

        // When
        sut.bluetoothTransportDidReceiveMessageData(statusOnlyCBOR)

        // Then - peer termination: no outbound signal, session destroyed, failed state
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)
    }

    // MARK: - DecryptionError triggers termination
    @Test("DecryptionError during processSessionEstablishment triggers full termination sequence")
    mutating func didReceiveDecryptionErrorTriggersTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        mockCryptoService.processSessionEstablishmentError = DecryptionError.authenticationError

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)

        // Then - SessionData with status 20 sent (no DeviceResponse payload for decryption errors)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))
        #expect(map[CBOR("data")] == nil)

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    @Test("CryptoServiceError during processSessionEstablishment triggers full termination sequence")
    mutating func didReceiveCryptoServiceErrorTriggersTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        mockCryptoService.processSessionEstablishmentError = CryptoServiceError.sessionCryptoContextNotFound

        sut = setupOrchestrator()
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)

        // Then - SessionData with status 20 sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))

        // Trigger send completion and wait for delayed GATT End
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    @Test("userDidTapCancel renders cancelled state from preflight")
    func userDidTapCancelRendersState() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .preflight)
        
        // When
        sut.userDidTapCancel()
        
        // Then — no confirmation, cancels directly
        #expect(mockDelegate.cancelConfirmationRequested == false)
        #expect(mockDelegate.stateToRender == .cancelled)
    }
    
    // MARK: - DeviceResponse tests
    @Test("Reader Authentication malformedDeviceRequest terminates with DeviceResponse error code 11")
    mutating func readerAuthMalformedRequestTerminatesWithDecodeError() async throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockReaderAuthenticator.errorToThrow = .malformedDeviceRequest
        sut = setupOrchestrator()
        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        let sessionData = SessionData(data: stubbedEncryptedResponse, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        // Reader Authentication runs asynchronously; wait for the termination.
        await eventually { mockCryptoService.passedDeviceResponse?.status == .cborDecodingError }
        
        // Then
        #expect(mockCryptoService.passedDeviceResponse?.status == .cborDecodingError)
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("Reader Authentication policy failure terminates with DeviceResponse error code 10")
    mutating func readerAuthPolicyFailureTerminatesWithGeneralError() async throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockReaderAuthenticator.errorToThrow = .untrustedReaderCertificate
        sut = setupOrchestrator()

        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        let sessionData = SessionData(data: stubbedEncryptedResponse, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        // Reader Authentication runs asynchronously; wait for the termination.
        await eventually { mockCryptoService.passedDeviceResponse?.status == .generalError }
        
        // Then
        #expect(mockCryptoService.passedDeviceResponse?.status == .generalError)
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("assembleAndEncryptResponse builds SessionData model with no DeviceResponse on generic didReceive failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnGenericRequessFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        let sessionData = SessionData(data: nil, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        mockCryptoService.proccessSessionEstablishmentShouldThrow = true
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("assembleAndEncryptResponse builds SessionData model with no DeviceResponse on encryption failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnEncryptionFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.setResponseDocType(.mdl)
        try session.setSessionTranscript(
            SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            )
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        
        let sessionData = SessionData(data: nil, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        mockCryptoService.encryptDeviceResponseError = .skDeviceKeyNotFound
        sut.assembleAndEncryptResponse()
        
        // Then
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    // MARK: - Sig_structure tests
    
    @Test("prepareDeviceSignedResponse renders error when session is nil")
    func constructSigStructureRendersErrorSessionNil() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        
        // When
        await sut.prepareDeviceSignedResponse()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("prepareDeviceSignedResponse triggers termination when constructSigStructure throws")
    mutating func constructSigStructureTriggersTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        
        // When
        mockCryptoService.constructSigStructureShouldThrow = true
        await sut.prepareDeviceSignedResponse()
        
        // Then
        let sessionData = SessionData(status: .sessionTermination)
        let expectedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        #expect(mockBluetoothTransport.lastSentSessionData == expectedBytes)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(session.currentState == .terminatingSession)
    }
    
    @Test("prepareDeviceSignedResponse triggers termination when sign throws")
    mutating func generateDeviceSignedTriggersTerminationOnSignFailure() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.errorToThrow = CredentialRequestError.matchedCredentialNotFound
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        
        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        
        // When
        await sut.prepareDeviceSignedResponse()
        
        // Then
        let sessionData = SessionData(status: .sessionTermination)
        let expectedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        #expect(mockBluetoothTransport.lastSentSessionData == expectedBytes)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(session.currentState == .terminatingSession)
    }

    @Test("prepareDeviceSignedResponse stores DeviceSigned with correct COSE_Sign1 structure on success")
    mutating func generateDeviceSignedStoresDeviceSignedOnSuccess() async throws {
        // Given
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.stubbedSignatureBytes = Data([0xAA, 0xBB])
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.stubbedSigStructureBytes = Data([0x01])

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        
        // Set matched credential
        let session = try #require(sut.session as? HolderSession)
        try session.setMatchedCredential(Credential(id: "mock-id", rawCredential: Data()))

        // Transition to awaitingUserConsent (signing now happens from this state)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then - DeviceSigned is populated with untagged COSE_Sign1
        let deviceSigned = try #require(session.deviceSigned)

        let cbor = deviceSigned.toCBOR()
        guard case let .map(map) = cbor,
              case let .map(authMap) = map[.utf8String("deviceAuth")],
              case let .array(coseSign1) = authMap[.utf8String("deviceSignature")] else {
            Issue.record("Expected deviceAuth.deviceSignature COSE_Sign1 array")
            return
        }

        #expect(coseSign1.count == 4)
        // Protected header: {1: -7} (ES256)
        guard case let .byteString(protectedHeaderBytes) = coseSign1[0] else {
            Issue.record("Expected protected header as byteString")
            return
        }
        let decodedHeader = try CBOR.decode(protectedHeaderBytes)
        #expect(decodedHeader == .map([.unsignedInt(1): .negativeInt(6)]))
        // Unprotected header: empty map
        #expect(coseSign1[1] == .map([:]))
        // Payload: null
        #expect(coseSign1[2] == .null)
        // Signature: raw bytes from sign()
        #expect(coseSign1[3] == .byteString([0xAA, 0xBB]))
    }

    // MARK: - Sign() Local Auth Error Handling

    @Test("Signing succeeds — transitions to processingResponse after signing in awaitingUserConsent")
    mutating func signingSucceedsTransitionsToProcessingResponse() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — signing occurred while in awaitingUserConsent, then transitioned
        #expect(mockHandler.didCallSignSigStructure == true)
        #expect(session.currentState.kind == .processingResponse)
    }

    @Test("User cancels signing — session stays active in awaitingUserConsent")
    mutating func localAuthCancelledKeepsSessionActive() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.signErrorToThrow = CredentialSigningError.recoverable
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — no DeviceResponse transmitted, session remains active
        #expect(session.currentState.kind == .awaitingUserConsent)
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(sut.session != nil)
    }

    @Test("Signing can be retried after LocalAuthCancelled")
    mutating func signingRetrySucceedsAfterCancellation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.signErrorToThrow = CredentialSigningError.recoverable
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // First attempt — cancelled
        await sut.prepareDeviceSignedResponse()
        #expect(session.currentState.kind == .awaitingUserConsent)

        // When — retry succeeds
        mockHandler.signErrorToThrow = nil
        await sut.prepareDeviceSignedResponse()

        // Then — sharing journey proceeds
        #expect(session.currentState.kind == .processingResponse)
    }

    @Test("User can deny sharing after LocalAuthCancelled")
    mutating func userCanDenyAfterCancellation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.signErrorToThrow = CredentialSigningError.recoverable
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // First attempt — cancelled
        await sut.prepareDeviceSignedResponse()
        #expect(session.currentState.kind == .awaitingUserConsent)

        // When — user denies sharing
        sut.userDidTapDeny()

        // Then — existing denial behaviour is followed
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
    }

    @Test("Fatal signing failure sends encrypted termination response")
    mutating func signErrorSendsEncryptedTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.signErrorToThrow = CredentialSigningError.unrecoverable
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — termination message sent and session enters terminatingSession
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(session.currentState == .terminatingSession)
    }

    @Test("Fatal signing failure sets DeviceResponse with nil documents and status ok")
    mutating func signErrorSetsDeviceResponseCorrectly() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.signErrorToThrow = CredentialSigningError.unrecoverable
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — DeviceResponse stored with nil documents and status .ok (0)
        let deviceResponse = try #require(session.deviceResponse)
        #expect(deviceResponse.documents == nil)
        #expect(deviceResponse.status == .ok)
    }

    // MARK: - Catch block coverage tests
    
    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        // Force session into a terminal state so transition to .readyToPresent throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.performPreflightChecks()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("prepareEngagement renders error when startAdvertising throws")
    mutating func prepareEngagementRendersErrorWhenStartAdvertisingThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.shouldThrowOnStartAdvertising = true
        
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        // When
        sut.startTransaction()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("presentQRCode re-presents engagement when called again while already presenting")
    mutating func presentQRCodeRePresentsWhenAlreadyPresenting() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        
        // startPresentation transitions through to .presentingEngagement
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)
        
        // When — calling didStartAdvertising again re-presents the engagement.
        // presentingEngagement -> presentingEngagement is a legal self-transition
        // (used by the hide path to vend a nil-payload presentation).
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then — remains presenting, not failed.
        #expect(sut.session?.currentState.kind == .presentingEngagement)
        #expect(mockDelegate.stateToRender?.kind == .presentingEngagement)
    }
    
    @Test("connectionDidConnect renders error when session transition throws")
    func connectionDidConnectRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        // Force session into a terminal state so transition to .processingEstablishment throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("userDidTapCancel does nothing when session is already in a terminal state")
    func userDidTapCancelInTerminalStateIsNoOp() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        
        // Force session into a terminal state
        try sut.session?.transition(to: .cancelled)
        mockDelegate.stateToRender = nil
        
        // When
        sut.userDidTapCancel()
        
        // Then — no-op, cannot cancel from a terminal state
        #expect(mockDelegate.stateToRender == nil)
        #expect(mockDelegate.cancelConfirmationRequested == false)
    }

    @Test(".didReceive calls handleNoMatchTermination when credentialRequestHandler throws CredentialRequestError")
    mutating func didReceiveHandlesNoMatchTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.errorToThrow = CredentialRequestError.noCredentialsReturned
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest())

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockBluetoothTransport.didCallSendSessionData == true }

        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
    }

    // MARK: - filterIssuerSigned tests

    @Test("filterIssuerSigned is called after successful credential validation")
    mutating func filterIssuerSignedCalledAfterValidation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        let mockHandler = MockCredentialRequestHandler()
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest())
        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockHandler.didCallFilterIssuerSigned == true }

        // Then
        #expect(mockHandler.didCallFilterIssuerSigned == true)
    }

    @Test("filterIssuerSigned transitions to awaitingUserConsent on success")
    mutating func filterIssuerSignedTransitionsToAwaitingUserConsent() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let docRequest = makeDocRequest()
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest(docRequest))

        let mockHandler = MockCredentialRequestHandler()
        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { sut.session?.currentState.kind == .awaitingUserConsent }

        // Then
        #expect(sut.session?.currentState.kind == .awaitingUserConsent)
        #expect(mockDelegate.stateToRender?.kind == .awaitingUserConsent)
    }

    @Test("filterIssuerSigned triggers No Match termination when filter throws noMatchingNameSpaces")
    mutating func filterIssuerSignedTriggersTerminationOnNoMatchingNameSpaces() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.noMatchingNameSpaces
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest())

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockBluetoothTransport.didCallSendSessionData == true }

        // Verify termination message was sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)

        // Manually trigger send completion
        sut.bluetoothTransportDidFinishSending()

        // Allow the 500ms delayed teardown to complete
        await eventually {
            mockBluetoothTransport.didCallSendGattEnd == true
        }

        // Then
        #expect(mockDelegate.stateToRender == .success(reason: .emptyResponse))
    }

    @Test("filterIssuerSigned triggers No Match termination when filter throws noMatchingAttributes")
    mutating func filterIssuerSignedTriggersTerminationOnNoMatchingAttributes() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.noMatchingAttributes
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest())

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockBluetoothTransport.didCallSendSessionData == true }

        // Verify termination message was sent
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)

        // Manually trigger send completion
        sut.bluetoothTransportDidFinishSending()

        // Allow the 500ms delayed teardown to complete
        await eventually {
            mockBluetoothTransport.didCallSendGattEnd == true
        }

        // Then
        #expect(mockDelegate.stateToRender == .success(reason: .emptyResponse))
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
    }

    // MARK: - DCMAW-18944: Consent Accept & Deny UI Logic
    @Test("Accept constructs DeviceResponse with documents and status 0, encrypts and wraps in SessionData with no status, transmits via BLE")
    mutating func acceptConstructsDeviceResponseWithDocumentsEncryptsAndTransmitsViaBLE() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.setResponseDocType(.mdl)
        try session.setSessionTranscript(
            SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            )
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        // When
        sut.assembleAndEncryptResponse()

        // Then - DeviceResponse has documents and status 0
        #expect(mockCryptoService.passedDeviceResponse?.documents != nil)
        #expect(mockCryptoService.passedDeviceResponse?.documents?.isEmpty == false)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
        #expect(mockCryptoService.passedDeviceResponse?.version == "1.0")

        // Then - SessionData transmitted via BLE with no status code
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("data")] != nil)
        #expect(map[CBOR("status")] == nil)
    }

    @Test("After acceptance and BLE transmission, state transitions to awaitingVerifierResolution")
    mutating func acceptTransitionsToSuccessAfterBLETransmission() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.setResponseDocType(.mdl)
        try session.setSessionTranscript(
            SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            )
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        // When
        sut.assembleAndEncryptResponse()

        // Then
        #expect(mockDelegate.stateToRender?.kind == .awaitingVerifierResolution)
    }

    @Test("Deny constructs DeviceResponse with status 0, no documents, encrypts and wraps in SessionData with status 20, transmits via BLE")
    mutating func denyConstructsEmptyDeviceResponseEncryptsAndTransmitsWithStatus20() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        sut.userDidTapDeny()

        // Then - DeviceResponse has no documents and status 0
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)

        // Then - SessionData transmitted via BLE with status 20
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))
    }

    @Test("After denial and BLE transmission, state transitions to .success(.denialResponse)")
    mutating func denyTransitionsToSuccessAfterBLETransmission() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        sut.userDidTapDeny()
        
        // Allow the 500ms delayed teardown to complete
        await eventually {
            mockDelegate.stateToRender == .success(reason: .denialResponse)
        }

        // Then - state transitions to .success(data: denialResponse, reason: .denialResponse)
    }
    
    @Test("filterIssuerSigned terminates with DeviceResponse status 10 when exceededAgeOverLimit is thrown")
    mutating func filterIssuerSignedTerminatesWithGeneralErrorOnExceededAgeOverLimit() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // The selected request asks for three age_over_NN elements, which exceeds
        // the filter's limit of two and triggers exceededAgeOverLimit.
        let docRequest = makeDocRequest(nameSpaces: [
            "org.iso.18013.5.1": [
                "age_over_18": false,
                "age_over_21": false,
                "age_over_16": false,
                "portrait": false
            ]
        ])
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest(docRequest))
        // swiftlint:disable:next line_length
        let rawCredential = Data(base64URLEncoded: "ompuYW1lU3BhY2VzonRvcmcuaXNvLjE4MDEzLjUuMS5HQoHYGFhRpGhkaWdlc3RJRAxxZWxlbWVudElkZW50aWZpZXJtd2Vsc2hfbGljZW5jZWZyYW5kb21QNQc4ty_4GCc5_X0FIxFf9WxlbGVtZW50VmFsdWX0cW9yZy5pc28uMTgwMTMuNS4xhtgYWFKkaGRpZ2VzdElECnFlbGVtZW50SWRlbnRpZmllcmtmYW1pbHlfbmFtZWZyYW5kb21QHPA1-aYTxYyXDpPga8JdgmxlbGVtZW50VmFsdWVjRG9l2BhYW6RoZGlnZXN0SUQJcWVsZW1lbnRJZGVudGlmaWVyamJpcnRoX2RhdGVmcmFuZG9tUO520QWmnv3ZKjodPtj4YTpsZWxlbWVudFZhbHVl2QPsajE5OTAtMDYtMTXYGFhPpGhkaWdlc3RJRAZxZWxlbWVudElkZW50aWZpZXJrYWdlX292ZXJfMThmcmFuZG9tUMXuD9q3H4Re9FXsw_N6iDJsZWxlbWVudFZhbHVl9dgYWE-kaGRpZ2VzdElECHFlbGVtZW50SWRlbnRpZmllcmthZ2Vfb3Zlcl8yMWZyYW5kb21QB4UsfF-gPnCpT1XhVwiRnGxlbGVtZW50VmFsdWX12BhYoqRoZGlnZXN0SUQAcWVsZW1lbnRJZGVudGlmaWVycmRyaXZpbmdfcHJpdmlsZWdlc2ZyYW5kb21QebAzXhYz5ZfawBzo-nLWd2xlbGVtZW50VmFsdWWBo3V2ZWhpY2xlX2NhdGVnb3J5X2NvZGVhQmppc3N1ZV9kYXRl2QPsajIwMjAtMDEtMDFrZXhwaXJ5X2RhdGXZA-xqMjAzMC0wMS0wMdgYWFykaGRpZ2VzdElEB3FlbGVtZW50SWRlbnRpZmllcnZ1bl9kaXN0aW5ndWlzaGluZ19zaWduZnJhbmRvbVB8_lE7s8kMzOkX2Pfxj_8-bGVsZW1lbnRWYWx1ZWJVS2ppc3N1ZXJBdXRohEOhASahGCFZAdYwggHSMIIBeaADAgECAhRNWsW03w4kSLcu-DByVtPa4cxbwDAKBggqhkjOPQQDAjA_MQswCQYDVQQGEwJVSzELMAkGA1UECAwCR0IxDTALBgNVBAoMBERWTEExFDASBgNVBAMMC2R2bGEuZ292LnVrMB4XDTI1MDYwNDE1MjAxN1oXDTI2MDYwNDE1MjAxN1owPzELMAkGA1UEBhMCVUsxCzAJBgNVBAgMAkdCMQ0wCwYDVQQKDAREVkxBMRQwEgYDVQQDDAtkdmxhLmdvdi51azBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABME7DvO4Tko41e6zPYSxAlcgKk7DClYytlbGUMb_pTWYfy_0sS1-abgnAxytgr0STRjX3_wVXhJtbJO6IpI1NJqjUzBRMB0GA1UdDgQWBBTQobpL3smcZBLCHdOb3Bx8wuhxqjAfBgNVHSMEGDAWgBTQobpL3smcZBLCHdOb3Bx8wuhxqjAPBgNVHRMBAf8EBTADAQH_MAoGCCqGSM49BAMCA0cAMEQCIGL4_6uPFvvNAoR_8vul6PPN9X7eubiAMUtqL8ZidJhbAiBFddvotS8QJrHUXS0ItWHbikowHHEduNPDoB5F1LtmwFkC-NgYWQLzpWd2ZXJzaW9uYzEuMG9kaWdlc3RBbGdvcml0aG1nU0hBLTI1Nmdkb2NUeXBldW9yZy5pc28uMTgwMTMuNS4xLm1ETGx2YWx1ZURpZ2VzdHOidG9yZy5pc28uMTgwMTMuNS4xLkdCoQxYIFfK7i-mXcn7zDaaMt3UwBlibwDuWI5yXNOIVjjKq4nVcW9yZy5pc28uMTgwMTMuNS4xrgFYIK_bpgqudgzuatHVcXiGKOnvkhQ2A5AvgdYKvIybvvTDClggVjoEqwVu_RPUy1Bw6hSggFEruyMbXxtainRi8uUzvLgJWCBT4r-uzM-x2LdRAfyEiGlH9CZx5aufBIrmQtDAn2iN6AZYIEVkz1OG8zqOuyS0oiXClRxHGwERHdnpXejeA4aILVrRCFggTVOp37d1Z8L6cPp7i30MxZzz1ef9rq5QXJes_EBRNg8CWCC5i-KQ2gPtfrqJzBn7Wa5RHpfan-FsQWHxGITimPuchgtYIIh8Fvqovz4DhT_G6X4ChPBnrBSCjoqLfWa8I7YVX_MtDlggfKvb4EsHzUqRyCvsrlebxaBAes5GJQxDzLpwr1_v7zgNWCCKgaDTbcLjttgtRo0GawJtiY7ZdvCrH_8Xx8gsufAYFQVYIGdJjomqXmlZcX8O_jTjlWEOQf5NbtiGfDIKV2lTFSl9BFggnHEfu8Ts7heL1CvgmNvJC5HTC2tpP6WQ-usfcN9pZRUDWCB7XkWTpcB61RaJS4RMRRrgbeeVNmLPUIQJNA5pvDvH1ABYILivJnFz2oHrps5F83OHUlbN6euCOll6Y8KbunPU1QIuB1ggB7SpkdOrsPrrPIkqyFVnFsOEPjEeCBkHlj8mfsitvwlsdmFsaWRpdHlJbmZvo2ZzaWduZWTAdDIwMjYtMDMtMTBUMTQ6MTk6MzNaaXZhbGlkRnJvbcB0MjAyNi0wMy0xMFQxNDoxOTozM1pqdmFsaWRVbnRpbMB0MjAyNy0wMy0xMFQxNDoxOTozM1pYQDixK8gqP2wizgyOpWaSv7G5tcKl5nJ7op-3i7naFLUX1QZsf2NXx-vUOpuwBa9kYIrhaLL0aqLh-xHZghS6AEk")
        let testCredentialProvider = TestCredentialProvider()
        testCredentialProvider.rawCredential = rawCredential
        sut = setupOrchestrator(credentialRequestHandler: CredentialRequestHandler(credentialProvider: testCredentialProvider))
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockBluetoothTransport.didCallSendSessionData == true }

        // Manually trigger send completion
        sut.bluetoothTransportDidFinishSending()

        // Allow the 500ms delayed teardown to complete
        await eventually {
            mockBluetoothTransport.didCallSendGattEnd == true
        }
        
        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .generalError)
    }

    @Test("filterIssuerSigned triggers termination with DeviceResponse status 10 when portraitNotRequested is thrown")
    mutating func filterIssuerSignedTriggersTerminationOnPortraitNotRequested() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.portraitNotRequested
        mockReaderAuthenticator.stubbedOutcome = .authenticated(makeAuthenticatedRequest())

        sut = setupOrchestrator(credentialRequestHandler: mockHandler)
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await eventually { mockBluetoothTransport.didCallSendSessionData == true }

        // Verify termination message was sent with DeviceResponse status 10 (generalError)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .generalError)

        // Manually trigger send completion
        sut.bluetoothTransportDidFinishSending()

        // Allow the 500ms delayed teardown to complete
        await eventually {
            sut.session == nil
        }

        // Then - full termination sequence completed
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockDelegate.stateToRender == .failed(.policyViolation(reason: "portraitNotRequested")))
    }

    // MARK: - userApprovedConsent
    @Test("userApprovedConsent notifies delegate with failed state when session is nil")
    func userApprovedConsentWithNoSession() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        #expect(sut.session == nil)

        // When
        sut.userDidTapApprove()

        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    @Test("userApprovedConsent transitions session to processingResponse after successful signing")
    mutating func userApprovedConsentTransitionsToProcessingResponse() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — after successful signing, transitions to processingResponse
        #expect(session.currentState.kind == .processingResponse)
    }

    @Test("prepareDeviceSignedResponse is no-op when session is in terminal state")
    mutating func userApprovedConsentRendersErrorWhenTransitionThrows() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()

        // Force session into a terminal state so signing cannot proceed
        try sut.session?.transition(to: .cancelled)

        // When
        await sut.prepareDeviceSignedResponse()

        // Then — session is in cancelled state (not awaitingUserConsent/processingResponse),
        // so the error catch guard returns without updating delegate
        #expect(sut.session?.currentState == .cancelled)
    }
    
    // MARK: GATT End Handling

    @Test("GATT End in awaitingVerifierResolution transitions to success(.responseSent)")
    mutating func gattEndInAwaitingVerifierResolutionTransitionsToSuccess() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        let document = Document(
            docType: .mdl,
            issuerSigned: IssuerSigned(nameSpaces: [:], issuerAuth: []),
            deviceSigned: DeviceSigned(nameSpaces: CBOR.map([:]).encode(), deviceAuth: DeviceAuth(deviceSignature: .array([])))
        )
        let response = DeviceResponse(documents: [document], status: .ok)
        try session.setDeviceResponse(response)
        try session.transition(to: .awaitingVerifierResolution)

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(mockDelegate.stateToRender == .success(reason: .responseSent))
        #expect(sut.session == nil)
    }

    @Test("GATT End in processingResponse transitions to failed(.transportError)")
    mutating func gattEndInProcessingResponseTransitionsToFailed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(mockDelegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("GATT End in awaitingUserConsent transitions to failed(.transportError)")
    mutating func gattEndInAwaitingUserConsentTransitionsToFailed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(mockDelegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("GATT End in processingEstablishment transitions to failed(.transportError)")
    mutating func gattEndInProcessingEstablishmentTransitionsToFailed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(mockDelegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("GATT End in terminatingSession is suppressed")
    mutating func gattEndInTerminatingSessionIsSuppressed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .terminatingSession)

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then — state remains terminatingSession, session not torn down
        #expect(sut.session?.currentState == .terminatingSession)
        #expect(sut.session != nil)
    }

    @Test("GATT End in success state is a no-op")
    mutating func gattEndInSuccessStateIsNoOp() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .success(reason: .responseSent))

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then — no state change
        #expect(sut.session?.currentState == .success(reason: .responseSent))
    }

    @Test("GATT End in failed state is a no-op")
    mutating func gattEndInFailedStateIsNoOp() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .failed(.generic("Already failed")))

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then — no state change
        #expect(sut.session?.currentState == .failed(.generic("Already failed")))
    }

    // MARK: BLE Disconnect (connectionTerminated) Handling

    @Test("BLE disconnect in processingEstablishment transitions to failed(.transportError)")
    mutating func bleDisconnectInProcessingEstablishmentTransitionsToFailed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidFail(with: .peripheral(.connectionTerminated))

        // Then
        #expect(mockDelegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("BLE disconnect in awaitingVerifierResolution transitions to success(.responseSent)")
    mutating func bleDisconnectInAwaitingVerifierResolutionTransitionsToSuccess() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        let document = Document(
            docType: .mdl,
            issuerSigned: IssuerSigned(nameSpaces: [:], issuerAuth: []),
            deviceSigned: DeviceSigned(nameSpaces: CBOR.map([:]).encode(), deviceAuth: DeviceAuth(deviceSignature: .array([])))
        )
        let response = DeviceResponse(documents: [document], status: .ok)
        try session.setDeviceResponse(response)
        try session.transition(to: .awaitingVerifierResolution)

        // When
        sut.bluetoothTransportDidFail(with: .peripheral(.connectionTerminated))

        // Then
        #expect(mockDelegate.stateToRender == .success(reason: .responseSent))
        #expect(sut.session == nil)
    }

    @Test("BLE disconnect in terminatingSession is suppressed")
    mutating func bleDisconnectInTerminatingSessionIsSuppressed() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? HolderSession)
        try session.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .terminatingSession)

        // When
        sut.bluetoothTransportDidFail(with: .peripheral(.connectionTerminated))

        // Then — state remains terminatingSession, session not torn down
        #expect(sut.session?.currentState == .terminatingSession)
        #expect(sut.session != nil)
    }

    // MARK: User Cancellation

    @Test("userDidTapCancel in processingEstablishment requests cancel confirmation")
    mutating func userDidTapCancelInProcessingEstablishmentRequestsConfirmation() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        #expect(sut.session?.currentState == .processingEstablishment)

        // When
        sut.userDidTapCancel()

        // Then — confirmation requested, session remains in current state
        #expect(mockDelegate.cancelConfirmationRequested == true)
        #expect(sut.session?.currentState == .processingEstablishment)
    }

    @Test("userDidTapCancel in awaitingUserConsent requests cancel confirmation")
    mutating func userDidTapCancelInAwaitingUserConsentRequestsConfirmation() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        try sut.session?.transition(to: .awaitingUserConsent(makeConsentPresentation()))

        // When
        sut.userDidTapCancel()

        // Then — confirmation requested, session remains in current state
        #expect(mockDelegate.cancelConfirmationRequested == true)
        #expect(sut.session?.currentState.kind == .awaitingUserConsent)
    }

    @Test("userDidTapCancel in processingResponse cancels directly without confirmation")
    mutating func userDidTapCancelInProcessingResponseCancelsDirectly() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        try sut.session?.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try sut.session?.transition(to: .processingResponse)

        // When
        sut.userDidTapCancel()

        // Then — no confirmation, cancels directly
        #expect(mockDelegate.cancelConfirmationRequested == false)
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("userDidTapCancel in awaitingVerifierResolution cancels directly without confirmation")
    mutating func userDidTapCancelInAwaitingVerifierResolutionCancelsDirectly() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        try sut.session?.transition(to: .awaitingUserConsent(makeConsentPresentation()))
        try sut.session?.transition(to: .processingResponse)
        try sut.session?.transition(to: .awaitingVerifierResolution)

        // When
        sut.userDidTapCancel()

        // Then — no confirmation, cancels directly
        #expect(mockDelegate.cancelConfirmationRequested == false)
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("userDidTapCancel in processingEstablishment sends GATT End only and transitions to cancelled")
    mutating func userDidTapCancelSendsGattEndAndCancels() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        #expect(sut.session?.currentState == .processingEstablishment)
        mockBluetoothTransport.didCallSendSessionData = false

        // When
        sut.userDidTapCancel()

        // Then — GATT End sent via ConnectionHandle teardown, no SessionData, session cancelled
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
        #expect(mockBlePeripheralTransport.endSessionAndNotifyValue == true)
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
        #expect(sut.bluetoothTransport == nil)
    }

    @Test("userDidTapCancel in presentingEngagement cancels directly without confirmation")
    mutating func userDidTapCancelInPresentingEngagementCancelsDirectly() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // When
        sut.userDidTapCancel()

        // Then — no confirmation dialog, proceeds directly to cancelled
        #expect(mockDelegate.cancelConfirmationRequested == false)
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }

    // MARK: - Inactivity Timer

    @Test("Inactivity timer starts when BLE connection is established")
    mutating func inactivityTimerStartsOnConnection() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()

        #expect(mockInactivityTimer.didCallStart == false)

        // When
        sut.bluetoothTransportConnectionDidConnect()

        // Then
        #expect(mockInactivityTimer.didCallStart == true)
        #expect(mockInactivityTimer.startCount == 1)
    }

    @Test("Inactivity timer resets on inbound BLE message")
    mutating func inactivityTimerResetsOnInboundMessage() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        #expect(mockInactivityTimer.didCallStart == true)
        #expect(mockInactivityTimer.didCallReset == false)

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.bluetoothTransportDidReceiveMessageData(data)

        // Then
        #expect(mockInactivityTimer.didCallReset == true)
        #expect(mockInactivityTimer.resetCount == 1)
    }

    @Test("Inactivity timer resets on outbound BLE send completion")
    mutating func inactivityTimerResetsOnOutboundSendCompletion() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        #expect(mockInactivityTimer.didCallStart == true)
        #expect(mockInactivityTimer.didCallReset == false)

        // When
        sut.bluetoothTransportDidFinishSending()

        // Then
        #expect(mockInactivityTimer.didCallReset == true)
        #expect(mockInactivityTimer.resetCount == 1)
    }

    @Test("Inactivity timeout sends GATT End, transitions to cancelled, and destroys session")
    mutating func inactivityTimeoutSendsGattEndTransitionsToCancelledAndDestroysSession() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        #expect(sut.session?.currentState == .processingEstablishment)
        #expect(mockBlePeripheralTransport.endSessionCalled == false)

        // When — simulate the timer firing
        sut.handleInactivityTimeout()

        // Then
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
        #expect(mockBlePeripheralTransport.endSessionAndNotifyValue == true)
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
        #expect(sut.inactivityTimer == nil)
    }

    @Test("Inactivity timeout does not fire when session is in terminal state")
    mutating func inactivityTimeoutDoesNotFireInTerminalState() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // Transition to a terminal state
        try? sut.session?.transition(to: .cancelled)
        mockDelegate.stateToRender = nil

        // When — simulate the timer firing
        sut.handleInactivityTimeout()

        // Then — GATT End should NOT have been sent, no state change
        #expect(mockBluetoothTransport.didCallSendGattEnd == false)
        #expect(mockDelegate.stateToRender == nil)
    }

    @Test("Inactivity timeout does not send SessionData status 20 — GATT End only")
    mutating func inactivityTimeoutSendsNoSessionData() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.autoCompleteSend = false
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()

        // When — simulate the timer firing
        sut.handleInactivityTimeout()

        // Then — only GATT End, no SessionData sent
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
        #expect(mockBlePeripheralTransport.endSessionAndNotifyValue == true)
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
    }

    @Test("Inactivity timer is stopped when session is torn down via userDidTapCancel")
    mutating func inactivityTimerStoppedOnTearDown() {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()

        #expect(sut.inactivityTimer != nil)
        #expect(mockInactivityTimer.didCallStop == false)

        // When — user cancels after prompt
        sut.userDidTapCancel()

        // Then
        #expect(mockInactivityTimer.didCallStop == true)
        #expect(sut.inactivityTimer == nil)
    }

    @Test("Inactivity timer is not started before BLE connection")
    mutating func inactivityTimerNotStartedBeforeConnection() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()

        // When
        sut.startTransaction()

        // Then
        #expect(mockInactivityTimer.didCallStart == false)
    }

    // MARK: - Engagement Lifetime (Hide + Expiry)

    @Test("Both engagement timers start when the QR is presented")
    mutating func engagementTimersStartOnPresentation() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()

        // When — startPresentation drives through to .presentingEngagement (advertising)
        sut.startTransaction()

        // Then — both the hide and expiry timers are scheduled from one instant
        #expect(sut.session?.currentState.kind == .presentingEngagement)
        #expect(mockEngagementHideTimer.didCallStart == true)
        #expect(mockEngagementHideTimer.startCount == 1)
        #expect(mockEngagementExpiryTimer.didCallStart == true)
        #expect(mockEngagementExpiryTimer.startCount == 1)
    }

    @Test("Hide timer hides the QR via a nil-payload presentation while advertising continues")
    mutating func engagementHideVendsNilPayloadPresentation() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // When — the hide timer fires
        sut.handleEngagementHide()

        // Then — still presenting, but with a hidden (nil) QR payload
        #expect(sut.session?.currentState.kind == .presentingEngagement)
        #expect(sut.session?.currentState == .presentingEngagement(
            EngagementPresentation(qrPayload: nil, cancelRequiresConfirmation: false)
        ))
        #expect(mockDelegate.stateToRender == .presentingEngagement(
            EngagementPresentation(qrPayload: nil, cancelRequiresConfirmation: false)
        ))
        // Advertising continues: the session is NOT torn down and the expiry timer is untouched.
        #expect(sut.session != nil)
        #expect(mockEngagementExpiryTimer.didCallStop == false)
    }

    @Test("Expiry tears down the session and refreshes in place without surfacing .expired")
    mutating func engagementExpiryRefreshesInPlace() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // When — the expiry timer fires. This marks the current session `.expired`,
        // tears it down (which clears the injected mock transport/crypto/gate), and
        // calls startTransaction() to begin a replacement session in place.
        sut.handleEngagementExpiry()

        // Then
        // 1. A replacement session was started (the orchestrator did not just stop).
        #expect(sut.session != nil)
        // 2. .expired is internal and must NEVER be delivered to the UI delegate.
        #expect(!mockDelegate.renderedStates.contains(.expired))
        // 3. The injected engagement timers were cleared by teardown so the expired
        //    session can no longer fire hide/expiry callbacks.
        #expect(mockEngagementHideTimer.didCallStop == true)
        #expect(mockEngagementExpiryTimer.didCallStop == true)
    }

    @Test("Verifier connection cancels both engagement timers")
    mutating func connectionCancelsEngagementTimers() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // When — a verifier connects (covers both the visible and grace windows)
        sut.bluetoothTransportConnectionDidConnect()

        // Then — both engagement timers are stopped and cleared
        #expect(mockEngagementHideTimer.didCallStop == true)
        #expect(mockEngagementExpiryTimer.didCallStop == true)
        #expect(sut.engagementTimers.hide == nil)
        #expect(sut.engagementTimers.expiry == nil)
        #expect(sut.session?.currentState.kind == .processingEstablishment)
    }

    @Test("Hide handler is a no-op once a verifier has connected")
    mutating func engagementHideNoOpAfterConnection() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        #expect(sut.session?.currentState.kind == .processingEstablishment)

        // When — a late hide timer callback fires
        sut.handleEngagementHide()

        // Then — the in-progress transaction is untouched
        #expect(sut.session?.currentState.kind == .processingEstablishment)
    }

    @Test("Expiry handler is a no-op once a verifier has connected")
    mutating func engagementExpiryNoOpAfterConnection() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.bluetoothTransportConnectionDidConnect()
        #expect(sut.session?.currentState.kind == .processingEstablishment)

        // When — a late expiry timer callback fires
        sut.handleEngagementExpiry()

        // Then — the connected session is not refreshed/destroyed
        #expect(sut.session?.currentState.kind == .processingEstablishment)
    }

    @Test("User cancel while presenting stops both engagement timers and cancels the session")
    mutating func userCancelStopsEngagementTimers() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // When — the user cancels (no prompt in presentingEngagement)
        sut.userDidTapCancel()

        // Then — both timers stopped and the session is torn down after cancellation
        #expect(mockEngagementHideTimer.didCallStop == true)
        #expect(mockEngagementExpiryTimer.didCallStop == true)
        #expect(sut.session == nil)
    }

    @Test("User cancel during the grace window still cancels the session")
    mutating func userCancelDuringGraceCancelsSession() {
        // Given — QR already hidden (grace window), still presentingEngagement
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startTransaction()
        sut.handleEngagementHide()
        #expect(sut.session?.currentState == .presentingEngagement(
            EngagementPresentation(qrPayload: nil, cancelRequiresConfirmation: false)
        ))

        // When
        sut.userDidTapCancel()

        // Then
        #expect(mockEngagementHideTimer.didCallStop == true)
        #expect(mockEngagementExpiryTimer.didCallStop == true)
        #expect(sut.session == nil)
    }

    // MARK: - Timing Values

    @Test("Engagement timing constants have their specified values")
    func engagementTimingConstantsAreCorrect() {
        #expect(EngagementTimers.engagementSessionLifetime == .seconds(300))
        #expect(EngagementTimers.engagementGracePeriod == .seconds(1))
        // Derived: QR is visible for the lifetime minus the grace window.
        #expect(EngagementTimers.engagementQRVisibleDuration == .seconds(299))
        #expect(
            EngagementTimers.engagementQRVisibleDuration
                == EngagementTimers.engagementSessionLifetime
                - EngagementTimers.engagementGracePeriod
        )
    }

    @Test("Inactivity timer default timeout is 300 seconds")
    func inactivityTimerDefaultTimeoutIsCorrect() {
        #expect(InactivityTimer<ContinuousClock>.defaultTimeout == .seconds(300))
    }

    /// Builds an orchestrator wired with the standard collaborator mocks but with the
    /// timers left un-injected (`nil`), so the orchestrator constructs its own real
    /// `InactivityTimer`s. `setupOrchestrator` always injects mock timers (which ignore
    /// duration), so it cannot be used to inspect the real durations.
    private func makeOrchestratorWithRealTimers() -> HolderOrchestrator {
        HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler,
            inactivityTimer: nil,
            engagementTimers: EngagementTimers(hide: nil, expiry: nil),
            readerAuthenticator: mockReaderAuthenticator,
            trustedReaderCertificates: (try? TestCertificate.issuer).map { [$0] } ?? [],
            supportedDocumentTypes: HolderOrchestrator.productSupportedDocumentTypes,
            syntheticPrivacyPolicyURL: URL(string: "https://www.gov.uk/")
        )
    }

    @Test("Inactivity timer is built with the default timeout duration")
    mutating func inactivityTimerBuiltWithDefaultTimeout() throws {
        // Given — no inactivity timer injected, so the orchestrator builds a real one.
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = makeOrchestratorWithRealTimers()
        sut.startTransaction()

        // When — the connection starts the inactivity timer (constructs the real timer).
        sut.bluetoothTransportConnectionDidConnect()

        // Then — the real timer carries the default timeout duration.
        let timer = try #require(sut.inactivityTimer as? InactivityTimer<ContinuousClock>)
        #expect(timer.duration == InactivityTimer<ContinuousClock>.defaultTimeout)
        #expect(timer.duration == .seconds(300))
    }

    @Test("Engagement hide and expiry timers are built with the correct durations")
    mutating func engagementTimersBuiltWithCorrectDurations() throws {
        // Given — no engagement timers injected, so the orchestrator builds real ones.
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = makeOrchestratorWithRealTimers()

        // When — startPresentation schedules the real engagement timers.
        sut.startTransaction()
        #expect(sut.session?.currentState.kind == .presentingEngagement)

        // Then — each timer carries the duration intended for its role. This fails if a
        // regression swaps the constants or changes either value.
        let hide = try #require(sut.engagementTimers.hide as? InactivityTimer<ContinuousClock>)
        let expiry = try #require(sut.engagementTimers.expiry as? InactivityTimer<ContinuousClock>)

        #expect(hide.duration == EngagementTimers.engagementQRVisibleDuration)
        #expect(hide.duration == .seconds(299))

        #expect(expiry.duration == EngagementTimers.engagementSessionLifetime)
        #expect(expiry.duration == .seconds(300))
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
