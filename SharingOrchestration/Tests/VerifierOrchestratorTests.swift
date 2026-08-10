import Foundation
import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import SwiftCBOR
import Testing

// swiftlint:disable file_length
@MainActor
@Suite("VerifierOrchestrator Tests")
// swiftlint:disable type_body_length
struct VerifierOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var mockBluetoothTransport = MockBluetoothTransport()
    var mockCryptoService = MockCryptoService()
    var sut: VerifierOrchestrator
    var mockInactivityTimer = MockInactivityTimer()

    let testAttributeGroup: AttributeGroup
    let missingPrerequisitesAllNotDetermined: [MissingPrerequisite] = [
        .camera(.authorizationNotDetermined),
        .bluetooth(.authorizationNotDetermined)
    ]

    init() throws {
        sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate)
        testAttributeGroup = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .portrait, intentToRetain: false),
                .init(attribute: .ageOver(21), intentToRetain: false)
            ]
        ))
    }

    private func setupOrchestrator(
        prerequisiteGate: PrerequisiteGateProtocol? = nil,
        bluetoothTransport: BluetoothTransportProtocol? = nil,
        cryptoService: CryptoServiceProtocol? = nil,
        inactivityTimer: InactivityTimerProtocol? = nil
    ) -> VerifierOrchestrator {
        VerifierOrchestrator(
            prerequisiteGate: prerequisiteGate ?? mockPrerequisiteGate,
            cryptoService: cryptoService ?? mockCryptoService,
            bluetoothTransport: bluetoothTransport ?? mockBluetoothTransport,
            inactivityTimer: inactivityTimer ?? mockInactivityTimer
        )
    }

    /// Builds valid CBOR-encoded SessionData bytes that will pass the connecting state validation gate.
    /// Contains a `data` field so it routes through to `didReceive`.
    private func buildValidSessionDataMessage() -> Data {
        let sessionData = SessionData(data: Data([0x01]))
        return Data(sessionData.encode(options: CBOROptions()))
    }

    /// Builds a valid CBOR-encoded DeviceResponse with status 0 and one document.
    private func buildValidDeviceResponseData() -> Data {
        let innerBytes = CBOR.map([
            .utf8String("digestID"): .unsignedInt(0),
            .utf8String("random"): .byteString([1, 2, 3, 4]),
            .utf8String("elementIdentifier"): .utf8String("family_name"),
            .utf8String("elementValue"): .utf8String("Smith")
        ]).encode()
        let issuerAuth: CBOR = .array([.byteString([]), .map([:]), .null, .byteString([1, 2, 3])])
        let document: CBOR = .map([
            .utf8String("docType"): .utf8String("org.iso.18013.5.1.mDL"),
            .utf8String("issuerSigned"): .map([
                .utf8String("nameSpaces"): .map([
                    .utf8String("org.iso.18013.5.1"): .array([
                        .tagged(.encodedCBORDataItem, .byteString(innerBytes))
                    ])
                ]),
                .utf8String("issuerAuth"): issuerAuth
            ])
        ])
        let response: CBOR = .map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("status"): .unsignedInt(0),
            .utf8String("documents"): .array([document])
        ])
        return Data(response.encode())
    }

    @Test("startVerification creates a new VerifierSession")
    func startVerificationCreatesSession() {
        // Given
        let sut = VerifierOrchestrator()
        #expect(sut.session == nil)

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(sut.session != nil)
    }

    @Test("cancelVerification releases the session")
    func cancelVerificationReleasesSession() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session != nil)

        // When
        sut.cancelVerification()

        // Then
        #expect(sut.session == nil)
    }

    @Test("cancelVerification notifies delegate with cancelled state")
    func cancelVerificationNotifiesDelegate() {
        // Given
        let sut = VerifierOrchestrator()
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.cancelVerification()

        // Then
        #expect(delegate.stateToRender == .cancelled)
    }

    @Test("startVerification after cancel creates a new session instance")
    func startAfterCancelCreatesNewSession() throws {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification(attributeGroup: testAttributeGroup)

        let firstSession = try #require(sut.session as? VerifierSession)

        // When
        sut.cancelVerification()
        sut.startVerification(attributeGroup: testAttributeGroup)

        let secondSession = try #require(sut.session as? VerifierSession)

        // Then
        #expect(firstSession !== secondSession)
    }

    @Test("cancelVerification on already cancelled session still releases")
    func cancelOnAlreadyCancelledStillReleases() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.cancelVerification()
        #expect(sut.session == nil)

        // When
        sut.cancelVerification()

        // Then
        #expect(sut.session == nil)
    }

    // MARK: - Preflight Tests

    @Test("Starting verification evaluates both camera and bluetooth prerequisites")
    func startVerificationEvaluatesCameraAndBluetoothPrerequisites() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.camera))
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.bluetooth))
    }

    @Test("startVerification evaluates the bluetooth prerequisite through the gate")
    func startVerificationEvaluatesBluetoothPrerequisite() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(sut.session?.currentState == .readyToScan)
    }

    @Test("Both camera and bluetooth missing prerequisites exposed in preflight")
    func cameraAndBluetoothMissingPrerequisitesExposedInPreflight() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = missingPrerequisitesAllNotDetermined

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        let expected: VerifierSessionState = .preflight(missingPrerequisites: missingPrerequisitesAllNotDetermined)
        #expect(sut.session?.currentState == expected)
        #expect(delegate.stateToRender == expected)
    }

    @Test("Bluetooth remains missing after camera has been resolved")
    func bluetoothRemainsMissingAfterCameraResolved() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = missingPrerequisitesAllNotDetermined
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When - camera resolved, bluetooth still missing
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.bluetooth(.authorizationNotDetermined)]
        sut.performPreflightChecks()

        // Then
        let expected: VerifierSessionState = .preflight(missingPrerequisites: [
            .bluetooth(.authorizationNotDetermined)
        ])
        #expect(sut.session?.currentState == expected)
        #expect(delegate.stateToRender == expected)
    }

    @Test("Camera remains missing after bluetooth has been resolved")
    func cameraRemainsMissingAfterBluetoothResolved() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = missingPrerequisitesAllNotDetermined
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When - bluetooth resolved, camera still missing
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.camera(.authorizationNotDetermined)]
        sut.performPreflightChecks()

        // Then
        let expected: VerifierSessionState = .preflight(missingPrerequisites: [
            .camera(.authorizationNotDetermined)
        ])
        #expect(sut.session?.currentState == expected)
        #expect(delegate.stateToRender == expected)
    }

    @Test("A recoverable missing prerequisite transitions to preflight")
    func recoverableMissingPrerequisiteExposesPreflight() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.bluetooth(.authorizationNotDetermined)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(sut.session?.currentState == .preflight(missingPrerequisites: [.bluetooth(.authorizationNotDetermined)]))
        #expect(delegate.stateToRender == .preflight(missingPrerequisites: [.bluetooth(.authorizationNotDetermined)]))
    }

    @Test("Completing prerequisite resolution re-runs preflight against camera and bluetooth")
    func completingResolutionReRunsPreflightAndUpdatesState() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = missingPrerequisitesAllNotDetermined
        
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(delegate.stateToRender == .preflight(missingPrerequisites: missingPrerequisitesAllNotDetermined))

        // When - all prerequisites resolved, preflight re-runs
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.performPreflightChecks()

        // Then
        #expect(delegate.stateToRender == .readyToScan)
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.camera))
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.bluetooth))
    }

    @Test("No missing prerequisites transitions to readyToScan")
    func noMissingPrerequisitesExposesReadyToScan() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(sut.session?.currentState == .readyToScan)
        #expect(delegate.stateToRender == .readyToScan)
    }

    @Test("Unrecoverable bluetooth prerequisite (denied) fails the journey")
    func unrecoverablePrerequisiteDeniedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.bluetooth(.authorizationDenied)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.bluetooth(.authorizationDenied))))
    }

    @Test("Unrecoverable bluetooth prerequisite (restricted) fails the journey")
    func unrecoverablePrerequisiteRestrictedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.bluetooth(.authorizationRestricted)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.bluetooth(.authorizationRestricted))))
    }

    @Test("Unrecoverable camera prerequisite (denied) fails the journey")
    func unrecoverableCameraPrerequisiteDeniedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.camera(.authorizationDenied)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.camera(.authorizationDenied))))
    }

    @Test("Unrecoverable camera prerequisite (restricted) fails the journey")
    func unrecoverableCameraPrerequisiteRestrictedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.camera(.authorizationRestricted)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.camera(.authorizationRestricted))))
    }

    @Test("Unrecoverable camera prerequisite (unsupported) fails the journey")
    func unrecoverableCameraPrerequisiteUnsupportedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.camera(.stateUnsupported)]

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.camera(.stateUnsupported))))
    }

    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given — session enters preflight (gate is retained)
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = [.bluetooth(.authorizationNotDetermined)]
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session?.currentState.kind == .preflight)

        // Force session into a terminal state
        try sut.session?.transition(to: .cancelled)

        // Make the gate return no missing prerequisites so it attempts .readyToScan transition
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // When
        sut.performPreflightChecks()

        // Then — transition from .cancelled to .readyToScan throws
        #expect(delegate.stateToRender?.kind == .failed)
    }

    @Test("cancelVerification releases prerequisiteGate")
    func cancelVerificationReleasesPrerequisiteGate() {
        // Given
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.prerequisiteGate != nil)
        
        // When
        sut.cancelVerification()
        
        // Then
        #expect(sut.prerequisiteGate == nil)
    }

    // MARK: - QR Code Scanning Tests
    @Test("Valid mdoc QR code transitions session to connecting")
    func validMdocQRTransitionsToConnecting() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(sut.session?.currentState == .connecting)
        #expect(delegate.stateToRender == .connecting)
    }

    @Test("Non-mdoc QR code transitions session to failed")
    func nonMdocQRTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.processQRCodeError = CryptoServiceError.nonMdocQRScanned
        sut.qrCodeScanned("no-mdoc-prefix")

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("Malformed mdoc QR code transitions session to failed")
    func malformedMdocQRTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.processQRCodeError = DeviceEngagementError.requestWasIncorrectlyStructured
        sut.qrCodeScanned("mdoc:invalid")

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("generateSessionEstablishment failure transitions session to failed")
    func generateSessionEstablishmentFailureTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = CryptoServiceError.sessionCryptoContextNotFound
        sut.generateSessionEstablishment()

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("qrCodeScanned without session notifies delegate of failure")
    func qrCodeScannedWithoutSessionNotifiesDelegate() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.delegate = delegate
        // Do not call startVerification — no session exists

        // When
        sut.qrCodeScanned("mdoc:someData")

        // Then
        #expect(delegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    @Test("qrCodeScanned transitions through processingEngagement before connecting")
    func qrCodeScannedTransitionsThroughProcessingEngagement() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then - processingEngagement is emitted before connecting
        #expect(delegate.statesReceived.contains(.processingEngagement))
        #expect(delegate.statesReceived.contains(.connecting))
        let processingIndex = delegate.statesReceived.firstIndex(of: .processingEngagement)
        let connectingIndex = delegate.statesReceived.firstIndex(of: .connecting)
        #expect(try #require(processingIndex) < #require(connectingIndex))
    }

    // MARK: - Scanning Lifecycle Tests

    @Test("connect is called after a valid QR code is processed")
    func startScanningCalledAfterValidQR() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(mockTransport.startScanningCalled == true)
    }

    @Test("BluetoothTransport receives session with the service UUID from DeviceEngagement")
    func transportReceivesCorrectServiceUUID() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(mockTransport.startScanningSession?.serviceUUID == mockCrypto.stubbedServiceUUID)
    }

    @Test("connect failure notifies delegate with failed state")
    func startScanningFailureNotifiesDelegate() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        mockTransport.startScanningShouldThrow = CentralError.serviceUUIDNotSet

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(delegate.stateToRender == .failed(.generic(CentralError.serviceUUIDNotSet.localizedDescription)))
    }

    @Test("BluetoothTransportDelegate notifies orchestrator on peripheral discovery")
    func delegateNotifiedOnDiscovery() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        sut.bluetoothTransportDidDiscover()

        // Then
        #expect(sut.session?.currentState == .connecting)
    }

    @Test("bluetoothTransportDidFail notifies delegate with failed state via handleConnectionLoss")
    func bluetoothTransportDidFailNotifiesDelegate() {
        // Given — session in connecting state where BLE failure is fatal
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        #expect(sut.session?.currentState == .connecting)

        // When
        sut.bluetoothTransportDidFail(with: .central(.notPoweredOn(.poweredOff)))

        // Then — routes through handleConnectionLoss → fatal in connecting → transportError
        #expect(delegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    // MARK: - Receive Message Data (processResponse)

    @Test("bluetoothTransportDidReceiveMessageData calls processResponse with message data")
    func receiveMessageDataCallsProcessResponse() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        let messageData = buildValidSessionDataMessage()

        // When
        sut.bluetoothTransportDidReceiveMessageData(messageData)

        // Then
        #expect(mockCrypto.didCallProcessResponse == true)
        #expect(mockCrypto.incomingProcessResponseMessageData == messageData)
    }

    @Test("bluetoothTransportDidReceiveMessageData transitions session to verifying then terminates on success")
    func receiveMessageDataTransitionsToVerifying() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // Stub a valid DeviceResponse so parsing succeeds
        let validDeviceResponse = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validDeviceResponse)

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — transitions through verifying to terminatingSession (success termination initiated)
        #expect(delegate.statesReceived.contains(.verifying))
        #expect(delegate.statesReceived.contains(.terminatingSession))
    }

    @Test("bluetoothTransportDidReceiveMessageData transitions to failed when processResponse throws")
    func receiveMessageDataTransitionsToFailedWhenProcessResponseThrows() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        mockCrypto.processResponseError = CryptoServiceError.sessionCryptoContextNotFound
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: - generateSessionEstablishment Tests

    @Test("generateSessionEstablishment passes DeviceRequest containing session docRequest")
    func generateSessionEstablishmentPassesCorrectDeviceRequest() throws {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.generateSessionEstablishment()

        // Then
        let passedRequest = try #require(mockCrypto.passedDeviceRequest)
        let expectedDocRequest = DocRequest(with: testAttributeGroup)
        #expect(passedRequest.docRequests == [expectedDocRequest])
    }

    @Test("generateSessionEstablishment with EncryptionError.encryptionFailed transitions to failed")
    func generateSessionEstablishmentEncryptionErrorTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = EncryptionError.encryptionFailed
        sut.generateSessionEstablishment()

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("generateSessionEstablishment failure tears down session")
    func generateSessionEstablishmentFailureTearDownsSession() {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session != nil)

        // When
        mockCrypto.generateSessionEstablishmentError = EncryptionError.encryptionFailed
        sut.generateSessionEstablishment()

        // Then
        #expect(sut.session == nil)
    }

    // MARK: - bluetoothTransportConnectionDidConnect Tests

    @Test("bluetoothTransportConnectionDidConnect calls generateSessionEstablishment")
    func bluetoothTransportConnectionDidConnectCallsGenerateSessionEstablishment() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(mockCrypto.didCallgenerateSessionEstablishment == false)

        // When
        sut.bluetoothTransportConnectionDidConnect()

        // Then
        #expect(mockCrypto.didCallgenerateSessionEstablishment == true)
    }

    @Test("bluetoothTransportConnectionDidConnect transitions to failed when generateSessionEstablishment throws")
    func bluetoothTransportConnectionDidConnectFailsGracefully() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = CryptoServiceError.sessionCryptoContextNotFound
        sut.bluetoothTransportConnectionDidConnect()

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: - constructDeviceRequest Tests

    @Test("generateSessionEstablishment without session reports failure to delegate")
    func generateSessionEstablishmentWithoutSessionReportsFailure() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        // Do not call startVerification — no session exists

        // When
        sut.generateSessionEstablishment()

        // Then
        #expect(delegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    // MARK: - Decryption Error Handling

    @Test("receiveMessageData transitions to failed when decryption throws payloadTooShort")
    func receiveMessageDataTransitionsToFailedOnPayloadTooShort() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — processResponse throws payloadTooShort
        mockCrypto.processResponseError = DecryptionError.payloadTooShort
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — session transitions to failed and is torn down
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("receiveMessageData transitions to failed when decryption throws authenticationError")
    func receiveMessageDataTransitionsToFailedOnAuthenticationError() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — processResponse throws authenticationError (tampered tag)
        mockCrypto.processResponseError = DecryptionError.authenticationError
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — session transitions to failed and is torn down
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("receiveMessageData transitions to failed when SKDevice key is not found")
    func receiveMessageDataTransitionsToFailedOnSKDeviceKeyNotFound() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — processResponse throws skDeviceKeyNotFound
        mockCrypto.processResponseError = CryptoServiceError.skDeviceKeyNotFound
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — session transitions to failed and is torn down
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: DeviceResponse received without status + validation fails

    @Test("Sends SessionData(20), waits 500ms, sends GATT End, transitions to failed, session destroyed")
    func fullTerminationSequence() async {
        // Given — Verifier in connecting state, BLE active
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )

        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives without a SessionData status code
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data([0x01]), status: nil)

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, SessionData(20) sent, GATT End NOT yet sent
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == true)
        #expect(mockTransport.didCallSendSessionData == true)
        #expect(mockTransport.didCallSendGattEnd == false)

        // When — send-completion arrives from BLE stack
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — GATT End sent after 500ms, failed state, session destroyed
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(delegate.stateToRender?.kind == .failed)
    }

    // MARK: DeviceResponse with status 20 + BLE open + validation fails

    @Test("Sends GATT End only, no termination message, transitions to failed, session destroyed")
    func gattEndOnlyWhenStatus20AndBLEOpen() {
        // Given — Verifier in connecting state, BLE active
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives WITH status 20 — peer has signalled terminal intent
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data(), status: .sessionTermination)

        // When — BLE is still open
        mockTransport.isConnected = true
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, GATT End sent, no SessionData(20) sent, then transitions to failed
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: DeviceResponse with status 20 + BLE closed + validation fails

    @Test("No outbound signal sent, transitions to failed, session destroyed")
    func noSignalWhenStatus20AndBLEClosed() {
        // Given — Verifier in connecting state, BLE was active but peer closed it
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives WITH status 20, payload contains a DeviceResponse with error status 10
        let errorResponse: CBOR = .map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("status"): .unsignedInt(10)
        ])
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data(errorResponse.encode()), status: .sessionTermination)

        // Peer has already closed the BLE connection
        mockTransport.isConnected = false

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, no outbound signals, then transitions to failed
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: DeviceResponse with status 0 but no documents + validation fails

    @Test("Terminates with documentNotReturned when status 0 and documents array is empty")
    func terminatesOnDocumentNotReturned() {
        // Given — Verifier in connecting state, BLE active
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives without SessionData status, payload has status 0 but no documents
        let emptyResponse: CBOR = .map([
            .utf8String("version"): .utf8String("1.0"),
            .utf8String("status"): .unsignedInt(0),
            .utf8String("documents"): .array([])
        ])
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data(emptyResponse.encode()), status: nil)

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession with documentNotReturned reason
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == true)
        #expect(mockTransport.didCallSendSessionData == true)
    }

    // MARK: DeviceResponse received without status + validation succeeds

    @Test("Sends SessionData(20), waits 500ms, sends GATT End, transitions to success, session destroyed")
    func fullTerminationSequenceOnValidationSuccess() async {
        // Given — Verifier in connecting state, BLE active
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )

        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives without a SessionData status code, with valid data
        let validResponseData = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validResponseData, status: nil)

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, SessionData(20) sent, GATT End NOT yet sent
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == true)
        #expect(mockTransport.didCallSendSessionData == true)
        #expect(mockTransport.didCallSendGattEnd == false)

        // When — send-completion arrives from BLE stack
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — GATT End sent after 500ms, success state, session destroyed
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(delegate.stateToRender?.kind == .success)
    }

    // MARK: DeviceResponse with status 20 + BLE open + validation succeeds

    @Test("Sends GATT End only, no termination message, transitions to success, session destroyed")
    func gattEndOnlyWhenStatus20AndBLEOpenOnValidationSuccess() {
        // Given — Verifier in connecting state, BLE active
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives WITH status 20 — peer has signalled terminal intent
        let validResponseData = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validResponseData, status: .sessionTermination)

        // When — BLE is still open
        mockTransport.isConnected = true
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, GATT End sent, no SessionData(20) sent, then transitions to success
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(delegate.stateToRender?.kind == .success)
        #expect(sut.session == nil)
    }

    // MARK: DeviceResponse with status 20 + BLE closed + validation succeeds

    @Test("No outbound signal sent, transitions to success, session destroyed")
    func noSignalWhenStatus20AndBLEClosedOnValidationSuccess() {
        // Given — Verifier in connecting state, BLE was active but peer closed it
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // DeviceResponse arrives WITH status 20, payload contains a valid DeviceResponse
        let validResponseData = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validResponseData, status: .sessionTermination)

        // Peer has already closed the BLE connection
        mockTransport.isConnected = false

        // When
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — Session sealed as .terminatingSession, no outbound signals, then transitions to success
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(delegate.stateToRender?.kind == .success)
        #expect(sut.session == nil)
    }

    // MARK: - Invalid message in connecting state

    @Test("Invalid message in connecting sends termination message and transitions to terminatingSession")
    func invalidMessageInConnectingSendsTerminationAndTransitions() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — invalid (non-SessionData) bytes arrive while in connecting
        let invalidMessage = Data([0xFF, 0xFE, 0xFD])
        sut.bluetoothTransportDidReceiveMessageData(invalidMessage)

        // Then — termination message sent, state transitions to terminatingSession
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == true)
        #expect(mockTransport.didCallSendSessionData == true)
    }

    @Test("Invalid message in connecting completes full termination sequence")
    func invalidMessageInConnectingCompletesTerminationSequence() async {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — invalid bytes arrive, triggering termination
        sut.bluetoothTransportDidReceiveMessageData(Data([0xFF, 0xFE]))

        // Then — GATT End not sent yet (waiting for send-completion)
        #expect(mockTransport.didCallSendGattEnd == false)

        // When — send-completion arrives from BLE stack
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — GATT End sent after 500ms, transitions to failed, session destroyed
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(delegate.stateToRender?.kind == .failed)
    }

    @Test("Invalid message in connecting does not call processResponse")
    func invalidMessageInConnectingDoesNotCallProcessResponse() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — invalid bytes arrive
        sut.bluetoothTransportDidReceiveMessageData(Data([0xFF, 0xFE]))

        // Then — processResponse is never called
        #expect(mockCrypto.didCallProcessResponse == false)
    }

    // MARK: - Malformed SessionData in connecting state

    @Test("Malformed SessionData in connecting sends termination message and transitions to terminatingSession")
    func malformedSessionDataInConnectingSendsTermination() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — valid CBOR map arrives but with neither status nor data (empty SessionData)
        let emptySessionData = SessionData(data: nil, status: nil)
        let emptySessionDataBytes = Data(emptySessionData.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(emptySessionDataBytes)

        // Then — termination message sent, state transitions to terminatingSession
        #expect(delegate.statesReceived.contains(.terminatingSession))
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == true)
        #expect(mockTransport.didCallSendSessionData == true)
    }

    @Test("Malformed SessionData in connecting completes full termination sequence")
    func malformedSessionDataInConnectingCompletesTerminationSequence() async {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — empty SessionData arrives
        let emptySessionData = SessionData(data: nil, status: nil)
        let emptySessionDataBytes = Data(emptySessionData.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(emptySessionDataBytes)

        // Then — GATT End not sent yet
        #expect(mockTransport.didCallSendGattEnd == false)

        // When — send-completion arrives
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — GATT End sent, transitions to failed, session destroyed
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(delegate.stateToRender?.kind == .failed)
    }

    @Test("Malformed SessionData in connecting does not call processResponse")
    func malformedSessionDataInConnectingDoesNotCallProcessResponse() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — empty SessionData arrives
        let emptySessionData = SessionData(data: nil, status: nil)
        let emptySessionDataBytes = Data(emptySessionData.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(emptySessionDataBytes)

        // Then — processResponse is never called
        #expect(mockCrypto.didCallProcessResponse == false)
    }

    // MARK: - SessionData with data and non-20 status in connecting state

    @Test("SessionData with data and non-20 status sends GATT End only, no termination message")
    func sessionDataWithNon20StatusAndDataSendsGattEndOnly() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — SessionData with data payload and non-20 status (e.g. 10) arrives
        let sessionDataWithNon20 = SessionData(data: Data([0x01, 0x02]), status: .sessionEncryption)
        let messageBytes = Data(sessionDataWithNon20.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — GATT End sent, no SessionData(20) sent
        #expect(mockTransport.didCallSendGattEnd == true)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == false)
    }

    @Test("SessionData with data and non-20 status does not process the data payload")
    func sessionDataWithNon20StatusDoesNotProcessData() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — SessionData with data and non-20 status arrives
        let sessionDataWithNon20 = SessionData(data: Data([0x01, 0x02]), status: .sessionEncryption)
        let messageBytes = Data(sessionDataWithNon20.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — processResponse is never called (data not processed)
        #expect(mockCrypto.didCallProcessResponse == false)
    }

    @Test("SessionData with data and non-20 status transitions to failed and destroys session")
    func sessionDataWithNon20StatusTransitionsToFailedAndDestroysSession() {
        // Given — Verifier in connecting state
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — SessionData with data and non-20 status arrives
        let sessionDataWithNon20 = SessionData(data: Data([0x01, 0x02]), status: .cborDecoding)
        let messageBytes = Data(sessionDataWithNon20.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — transitions to failed, session destroyed
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: - Peer termination (status-only SessionData) in connecting state (DCMAW-21183)

    @Test("AC1: Status-only SessionData in connecting with BLE open sends no outbound signal")
    func peerTerminationInConnectingBLEOpenSendsNoOutboundSignal() {
        // Given — Verifier in connecting state, BLE channel open
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.isConnected = true
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — status-only SessionData (peer termination) arrives
        let statusOnly = SessionData(data: nil, status: .sessionTermination)
        let messageBytes = Data(statusOnly.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — no GATT End sent, no termination message sent
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == false)
    }

    @Test("AC1: Status-only SessionData in connecting with BLE open transitions to failed(.peerTermination)")
    func peerTerminationInConnectingBLEOpenTransitionsToFailed() {
        // Given — Verifier in connecting state, BLE channel open
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.isConnected = true
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — status-only SessionData arrives
        let statusOnly = SessionData(data: nil, status: .sessionTermination)
        let messageBytes = Data(statusOnly.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — transitions to failed(.peerTermination), session destroyed
        #expect(delegate.stateToRender == .failed(.peerTermination))
        #expect(sut.session == nil)
    }

    @Test("AC2: Status-only SessionData in connecting with BLE closed sends no outbound signal")
    func peerTerminationInConnectingBLEClosedSendsNoOutboundSignal() {
        // Given — Verifier in connecting state, BLE channel closed
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.isConnected = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — status-only SessionData arrives
        let statusOnly = SessionData(data: nil, status: .sessionTermination)
        let messageBytes = Data(statusOnly.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — no GATT End sent, no termination message sent
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockCrypto.didCallBuildTerminationMessageVerifier == false)
    }

    @Test("AC2: Status-only SessionData in connecting with BLE closed transitions to failed(.protocolError)")
    func protocolErrorInConnectingBLEClosedTransitionsToFailed() {
        // Given — Verifier in connecting state, BLE channel closed
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.isConnected = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — status-only SessionData arrives
        let statusOnly = SessionData(data: nil, status: .cborDecoding)
        let messageBytes = Data(statusOnly.encode(options: CBOROptions()))
        sut.bluetoothTransportDidReceiveMessageData(messageBytes)

        // Then — transitions to failed(.protocolError), session destroyed
        #expect(delegate.stateToRender == .failed(.protocolError))
        #expect(sut.session == nil)
    }

    // MARK: - Data ignored in verifying state

    @Test("AC3: Data arriving in verifying state is ignored and validation succeeds")
    func dataIgnoredInVerifyingStateValidationSucceeds() async {
        // Given — Verifier reaches verifying state via valid SessionData with data
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // Stub processResponse to return valid decrypted data
        let validDeviceResponseData = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validDeviceResponseData, status: .sessionTermination)

        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Trigger the first message to move to verifying
        let validMessage = buildValidSessionDataMessage()
        sut.bluetoothTransportDidReceiveMessageData(validMessage)

        // Confirm we're now in verifying (or terminatingSession after immediate processing)
        #expect(delegate.statesReceived.contains(.verifying))

        // When — additional data arrives while in verifying/terminatingSession
        let extraData = Data([0xAA, 0xBB, 0xCC])
        sut.bluetoothTransportDidReceiveMessageData(extraData)

        // Then - extra data does not trigger another processResponse call
        // processResponse is called exactly once (from the first message)
        #expect(mockCrypto.didCallProcessResponse == true)
        #expect(mockCrypto.incomingProcessResponseMessageData == validMessage)

        // Complete the termination sequence to reach success
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — session reaches success
        #expect(delegate.stateToRender?.kind == .success)
    }

    @Test("AC4: Data arriving in verifying state is ignored and validation fails")
    func dataIgnoredInVerifyingStateValidationFails() async {
        // Given — Verifier reaches verifying state but processResponse throws
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // Stub processResponse to return data that fails DeviceResponse parsing
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data([0xFF]), status: nil)

        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Trigger the first message to move to verifying — DeviceResponse parse will fail
        let validMessage = buildValidSessionDataMessage()
        sut.bluetoothTransportDidReceiveMessageData(validMessage)

        // Confirm verifying was reached
        #expect(delegate.statesReceived.contains(.verifying))

        // When — additional data arrives while in terminatingSession/failed
        let extraData = Data([0xAA, 0xBB, 0xCC])
        sut.bluetoothTransportDidReceiveMessageData(extraData)

        // Then — extra data is ignored, processResponse called only once
        #expect(mockCrypto.incomingProcessResponseMessageData == validMessage)

        // Complete the termination sequence
        sut.bluetoothTransportDidFinishSending()
        await eventually {
            sut.session == nil
        }

        // Then — session reaches failed
        #expect(delegate.stateToRender?.kind == .failed)
    }

    // MARK: - bluetoothTransportDidStartSession / send Tests

    @Test("bluetoothTransportDidStartSession calls send with session establishment bytes")
    func bluetoothTransportDidStartSessionCallsSend() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let sessionEstablishmentData = Data([0x01, 0x02, 0x03, 0x04])
        mockCrypto.stubbedSessionEstablishmentBytes = sessionEstablishmentData
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        // Simulate connection → generates session establishment
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(mockTransport.sendCalled == true)
        #expect(mockTransport.lastSentData == sessionEstablishmentData)
    }

    @Test("bluetoothTransportDidStartSession without session notifies delegate of failure")
    func bluetoothTransportDidStartSessionWithoutSessionNotifiesFailure() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate)
        sut.delegate = delegate
        // Do not call startVerification — no session exists

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(delegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    @Test("bluetoothTransportDidStartSession without session establishment bytes transitions to failed")
    func bluetoothTransportDidStartSessionWithoutBytesTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // Do NOT set stubbedSessionEstablishmentBytes — leaves sessionEstablishmentBytes nil
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("bluetoothTransportDidStartSession without session establishment bytes does not call send")
    func bluetoothTransportDidStartSessionWithoutBytesDoesNotCallSend() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(mockTransport.sendCalled == false)
    }

    @Test("bluetoothTransportDidStartSession tears down session when session establishment bytes are missing")
    func bluetoothTransportDidStartSessionTearsDownOnMissingBytes() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport
        )
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()
        #expect(sut.session != nil)

        // When
        sut.bluetoothTransportDidStartSession()

        // Then
        #expect(sut.session == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(sut.cryptoService == nil)
    }

    // MARK: - User Cancellation (DCMAW-21185)

    @Test("AC1: cancelVerification in connecting state requests cancel confirmation")
    func cancelVerificationInConnectingRequestsConfirmation() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        #expect(sut.session?.currentState == .connecting)

        // When
        sut.cancelVerification()

        // Then — confirmation requested, session remains in current state
        #expect(delegate.cancelConfirmationRequested == true)
        #expect(sut.session?.currentState == .connecting)
    }

    @Test("AC1: cancelVerification in verifying state requests cancel confirmation")
    func cancelVerificationInVerifyingRequestsConfirmation() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let validDeviceResponse = buildValidDeviceResponseData()
        mockCrypto.stubbedProcessResponseResult = SessionData(data: validDeviceResponse)
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockTransport,
            gattEndDelay: 0
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        sut.bluetoothTransportConnectionDidConnect()

        // Manually transition to verifying to test cancel in that state
        try? sut.session?.transition(to: .verifying)
        delegate.cancelConfirmationRequested = false

        // When
        sut.cancelVerification()

        // Then — confirmation requested, session remains in verifying
        #expect(delegate.cancelConfirmationRequested == true)
        #expect(sut.session?.currentState == .verifying)
    }

    @Test("AC2: userDidConfirmCancel sends GATT End only and transitions to cancelled")
    func userDidConfirmCancelSendsGattEndAndTransitionsToCancelled() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        #expect(sut.session?.currentState == .connecting)
        mockBluetoothTransport.didCallSendSessionData = false

        // When
        sut.userDidConfirmCancel()

        // Then — GATT End sent, no SessionData, session cancelled and destroyed
        #expect(mockBluetoothTransport.didCallSendGattEnd == true)
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
        #expect(delegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
        #expect(sut.bluetoothTransport == nil)
    }

    @Test("AC2: userDidConfirmCancel destroys session data")
    func userDidConfirmCancelDestroysSessionData() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        sut.userDidConfirmCancel()

        // Then — all session-related state destroyed
        #expect(sut.session == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(sut.cryptoService == nil)
        #expect(sut.prerequisiteGate == nil)
    }

    @Test("AC3: Dismissing confirmation dialog leaves session in current state")
    func cancelConfirmationDismissedSessionRemains() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        #expect(sut.session?.currentState == .connecting)

        // When — user taps cancel, dialog shown, then user taps 'No' (no confirm)
        sut.cancelVerification()

        // Then — confirmation was requested but session stays in connecting
        #expect(delegate.cancelConfirmationRequested == true)
        #expect(sut.session?.currentState == .connecting)
        #expect(sut.bluetoothTransport != nil)
    }

    @Test("AC4: cancelVerification in notStarted cancels directly without confirmation")
    func cancelVerificationInNotStartedCancelsDirectly() {
        // Given
        let sut = VerifierOrchestrator()
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        // Force back to notStarted for testing (normally not possible but tests the switch case)
        // Use preflight instead which is the natural pre-BLE state
        #expect(delegate.cancelConfirmationRequested == false)

        // When — cancel from readyToScan (the natural pre-BLE state with no prerequisites)
        sut.cancelVerification()

        // Then — no confirmation, cancels directly
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("AC4: cancelVerification in preflight cancels directly without confirmation")
    func cancelVerificationInPreflightCancelsDirectly() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = [
            .bluetooth(.authorizationNotDetermined)
        ]
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session?.currentState.kind == .preflight)

        // When
        sut.cancelVerification()

        // Then — no confirmation, cancels directly
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("AC4: cancelVerification in readyToScan cancels directly without confirmation")
    func cancelVerificationInReadyToScanCancelsDirectly() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session?.currentState == .readyToScan)

        // When
        sut.cancelVerification()

        // Then — no confirmation, cancels directly
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("AC4: cancelVerification in processingEngagement cancels directly without confirmation")
    func cancelVerificationInProcessingEngagementCancelsDirectly() {
        // Given
        let mockCrypto = MockCryptoService()
        mockCrypto.processQRCodeError = nil
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Manually transition to processingEngagement
        try? sut.session?.transition(to: .processingEngagement)
        delegate.cancelConfirmationRequested = false

        // When
        sut.cancelVerification()

        // Then — no confirmation, cancels directly
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
    }

    @Test("AC5: cancelVerification in terminal state (success) is no-op")
    func cancelVerificationInSuccessStateIsNoOp() throws {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Force to terminal state
        try sut.session?.transition(to: .terminatingSession)
        let deviceResponse = try DeviceResponse(data: buildValidDeviceResponseData())
        try sut.session?.transition(to: .success(deviceResponse))
        delegate.stateToRender = nil
        delegate.cancelConfirmationRequested = false

        // When
        sut.cancelVerification()

        // Then — no-op
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == nil)
    }

    @Test("AC5: cancelVerification in terminal state (failed) is no-op")
    func cancelVerificationInFailedStateIsNoOp() throws {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            cryptoService: mockCrypto,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Force to failed state
        try sut.session?.transition(to: .failed(.generic("test error")))
        delegate.stateToRender = nil
        delegate.cancelConfirmationRequested = false

        // When
        sut.cancelVerification()

        // Then — no-op
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == nil)
    }

    @Test("AC5: cancelVerification in cancelled state is no-op")
    func cancelVerificationInCancelledStateIsNoOp() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Force to cancelled state
        try sut.session?.transition(to: .cancelled)
        delegate.stateToRender = nil
        delegate.cancelConfirmationRequested = false

        // When
        sut.cancelVerification()

        // Then — no-op
        #expect(delegate.cancelConfirmationRequested == false)
        #expect(delegate.stateToRender == nil)
    }

    @Test("cancelVerification with nil session does nothing")
    func cancelVerificationWithNilSessionDoesNothing() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator()
        sut.delegate = delegate
        #expect(sut.session == nil)

        // When
        sut.cancelVerification()

        // Then — no error, no state change
        #expect(delegate.stateToRender == nil)
        #expect(delegate.cancelConfirmationRequested == false)
    }

    @Test("userDidConfirmCancel with nil session does nothing")
    func userDidConfirmCancelWithNilSessionDoesNothing() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator()
        sut.delegate = delegate
        #expect(sut.session == nil)

        // When
        sut.userDidConfirmCancel()

        // Then — no error, no state change
        #expect(delegate.stateToRender == nil)
    }

    // MARK: - Timeout Verifier Tests

    @Test("Inactivity timer starts when BLE connection is established")
    mutating func inactivityTimerStartsOnConnection() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()
        sut.startVerification(attributeGroup: testAttributeGroup)

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
        sut.startVerification(attributeGroup: testAttributeGroup)
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
        sut.startVerification(attributeGroup: testAttributeGroup)
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
        let mockDelegate = MockVerifierOrchestratorDelegate()
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.bluetoothTransportConnectionDidConnect()
        sut.qrCodeScanned("mdoc:validEngagementData")

        #expect(sut.session?.currentState == .connecting)
        #expect(mockBlePeripheralTransport.endSessionCalled == false)

        // When — simulate the timer firing
        sut.handleInactivityTimeout()

        // Then
        #expect(mockDelegate.stateToRender == .cancelled)
        #expect(sut.session == nil)
        #expect(sut.inactivityTimer == nil)
    }

    @Test("Inactivity timeout does not fire when session is in terminal state")
    mutating func inactivityTimeoutDoesNotFireInTerminalState() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let mockDelegate = MockVerifierOrchestratorDelegate()
        sut = setupOrchestrator()
        sut.delegate = mockDelegate
        sut.startVerification(attributeGroup: testAttributeGroup)
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
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.bluetoothTransportConnectionDidConnect()
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When — simulate the timer firing
        sut.handleInactivityTimeout()

        // Then — only GATT End, no SessionData sent
        #expect(mockBluetoothTransport.didCallSendSessionData == false)
    }

    @Test("Inactivity timer is not started before BLE connection")
    mutating func inactivityTimerNotStartedBeforeConnection() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = setupOrchestrator()

        // When
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Then
        #expect(mockInactivityTimer.didCallStart == false)
    }
    
    // MARK: Fatal GATT End/disconnect during connecting state

    @Test("GATT End in connecting state transitions to failed with transportError")
    func gattEndInConnectingStateTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(delegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("BLE disconnect in connecting state transitions to failed with transportError")
    func bleDisconnectInConnectingStateTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        sut.bluetoothTransportDidFail(with: .central(.connectError))

        // Then
        #expect(delegate.stateToRender == .failed(.transportError))
        #expect(sut.session == nil)
    }

    @Test("GATT End in connecting state destroys session data")
    func gattEndInConnectingStateDestroysSession() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(sut.session == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(sut.cryptoService == nil)
    }
    
    // MARK: Non-interrupting GATT End/disconnect during verifying (validation succeeds)

    @Test("GATT End in verifying state sets connectionLost flag without interrupting")
    func gattEndInVerifyingStateSetsConnectionLostFlag() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try? sut.session?.transition(to: .verifying)

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(sut.connectionLost == true)
        #expect(sut.session != nil)
        #expect(sut.session?.currentState == .verifying)
    }

    @Test("GATT End during verifying skips outbound signals")
    func validationSucceedsAfterGattEndSkipsOutboundSignals() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try? sut.session?.transition(to: .verifying)

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockTransport.didCallSendGattEnd == false)
    }

    @Test("initiateTermination with connectionLost skips outbound signals and transitions to terminal state")
    func initiateTerminationWithConnectionLostSkipsSignals() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        mockCrypto.stubbedProcessResponseResult = SessionData(data: buildValidDeviceResponseData())

        // Simulate that connection was lost during verifying
        sut.connectionLost = true
        mockTransport.didCallSendSessionData = false
        mockTransport.didCallSendGattEnd = false

        // When — receive message triggers validation → initiateTermination checks connectionLost
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — no outbound SessionData(20) or GATT End sent, transitions to success
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(delegate.stateToRender?.kind == .success)
        #expect(sut.session == nil)
    }

    // MARK: Non-interrupting GATT End/disconnect during verifying (validation fails)

    @Test("BLE disconnect in verifying state sets connectionLost flag")
    func bleDisconnectInVerifyingStateSetsConnectionLostFlag() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try? sut.session?.transition(to: .verifying)

        // When
        sut.bluetoothTransportDidFail(with: .central(.transportError("Connection lost")))

        // Then
        #expect(sut.connectionLost == true)
        #expect(sut.session?.currentState == .verifying)
    }

    @Test("initiateTermination with connectionLost and failed validation skips signals and transitions to failed")
    func initiateTerminationWithConnectionLostAndFailedValidation() {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Stub invalid DeviceResponse so validation fails
        mockCrypto.stubbedProcessResponseResult = SessionData(data: Data([0x01, 0x02, 0x03]))

        // Simulate that connection was lost during verifying
        sut.connectionLost = true
        mockTransport.didCallSendSessionData = false
        mockTransport.didCallSendGattEnd = false

        // When — receive message triggers validation, fails and initiateTermination checks connectionLost
        sut.bluetoothTransportDidReceiveMessageData(buildValidSessionDataMessage())

        // Then — no outbound SessionData(20) or GATT End sent, transitions to failed
        #expect(mockTransport.didCallSendSessionData == false)
        #expect(mockTransport.didCallSendGattEnd == false)
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    // MARK: - Already terminal state ignores GATT End/disconnect

    @Test("GATT End in success state is a no-op")
    func gattEndInSuccessStateIsNoOp() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try sut.session?.transition(to: .verifying)
        try sut.session?.transition(to: .terminatingSession)
        let deviceResponse = try DeviceResponse(data: buildValidDeviceResponseData())
        try sut.session?.transition(to: .success(deviceResponse))
        delegate.statesReceived = []

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(delegate.statesReceived.isEmpty)
        #expect(sut.session?.currentState.kind == .success)
    }

    @Test("GATT End in failed state is a no-op")
    func gattEndInFailedStateIsNoOp() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try sut.session?.transition(to: .failed(.generic("test error")))
        delegate.statesReceived = []

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(delegate.statesReceived.isEmpty)
        #expect(sut.session?.currentState == .failed(.generic("test error")))
    }

    @Test("GATT End in cancelled state is a no-op")
    func gattEndInCancelledStateIsNoOp() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try sut.session?.transition(to: .cancelled)
        delegate.statesReceived = []

        // When
        sut.bluetoothTransportDidFail(with: .central(.connectError))

        // Then
        #expect(delegate.statesReceived.isEmpty)
        #expect(sut.session?.currentState == .cancelled)
    }

    // MARK: During ordered teardown (terminatingSession), suppress inbound signals

    @Test("GATT End in terminatingSession state is suppressed")
    func gattEndInTerminatingSessionIsSuppressed() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try sut.session?.transition(to: .verifying)
        try sut.session?.transition(to: .terminatingSession)
        delegate.statesReceived = []

        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()

        // Then
        #expect(delegate.statesReceived.isEmpty)
        #expect(sut.session?.currentState == .terminatingSession)
    }

    @Test("BLE disconnect in terminatingSession state is suppressed")
    func bleDisconnectInTerminatingSessionIsSuppressed() throws {
        // Given
        let mockCrypto = MockCryptoService()
        let mockTransport = MockBluetoothTransport()
        mockTransport.autoCompleteSend = false
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = setupOrchestrator(bluetoothTransport: mockTransport, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)
        sut.qrCodeScanned("mdoc:validEngagementData")
        try sut.session?.transition(to: .verifying)
        try sut.session?.transition(to: .terminatingSession)
        delegate.statesReceived = []

        // When
        sut.bluetoothTransportDidFail(with: .central(.transportError("Connection lost")))

        // Then
        #expect(delegate.statesReceived.isEmpty)
        #expect(sut.session?.currentState == .terminatingSession)
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
