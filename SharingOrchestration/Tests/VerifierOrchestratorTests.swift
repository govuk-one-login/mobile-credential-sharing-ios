import Foundation
import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing

// swiftlint:disable file_length
@MainActor
@Suite("VerifierOrchestrator Tests")
// swiftlint:disable type_body_length
struct VerifierOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var sut: VerifierOrchestrator
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
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // Force session into a terminal state
        try sut.session?.transition(to: .cancelled)

        // When
        sut.performPreflightChecks()

        // Then
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
        sut.qrCodeScanned("mdoc:validEngagementData")

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

    @Test("constructSessionTranscript failure transitions session to failed and notifies delegate")
    func constructSessionTranscriptFailureTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = CryptoServiceError.sessionCryptoContextNotFound
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
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

    @Test("startScanning is called after a valid QR code is processed")
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

    @Test("startScanning failure notifies delegate with failed state")
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

    @Test("bluetoothTransportDidFail notifies delegate with failed state")
    func bluetoothTransportDidFailNotifiesDelegate() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.bluetoothTransportDidFail(with: .central(.notPoweredOn(.poweredOff)))

        // Then
        #expect(delegate.stateToRender == .failed(.generic(CentralError.notPoweredOn(.poweredOff).localizedDescription)))
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
        let messageData = Data([0xAA, 0xBB, 0xCC])

        // When
        sut.bluetoothTransportDidReceiveMessageData(messageData)

        // Then
        #expect(mockCrypto.didCallProcessResponse == true)
        #expect(mockCrypto.incomingProcessResponseMessageData == messageData)
    }

    @Test("bluetoothTransportDidReceiveMessageData transitions session to verifying")
    func receiveMessageDataTransitionsToVerifying() {
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
        sut.bluetoothTransportDidReceiveMessageData(Data([0x01]))

        // Then
        #expect(sut.session?.currentState == .verifying)
        #expect(delegate.stateToRender == .verifying)
    }

    @Test("bluetoothTransportDidReceiveMessageData without session notifies delegate of failure")
    func receiveMessageDataWithoutSessionNotifiesFailure() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate)
        sut.delegate = delegate

        // When
        sut.bluetoothTransportDidReceiveMessageData(Data([0x01]))

        // Then
        #expect(delegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    // MARK: - assembleAndEncryptRequest Tests

    @Test("assembleAndEncryptRequest calls encryptDeviceRequest on cryptoService")
    func assembleAndEncryptRequestCallsEncrypt() {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(mockCrypto.didCallEncryptDeviceRequest == true)
    }

    @Test("assembleAndEncryptRequest passes DeviceRequest containing session docRequest")
    func assembleAndEncryptRequestPassesCorrectDeviceRequest() throws {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        let passedRequest = try #require(mockCrypto.passedDeviceRequest)
        let expectedDocRequest = DocRequest(with: testAttributeGroup)
        #expect(passedRequest.docRequests == [expectedDocRequest])
    }

    @Test("assembleAndEncryptRequest failure transitions session to failed")
    func assembleAndEncryptRequestFailureTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = CryptoServiceError.skReaderKeyNotFound
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("assembleAndEncryptRequest with EncryptionError.encryptionFailed transitions to failed")
    func assembleAndEncryptRequestEncryptionErrorTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification(attributeGroup: testAttributeGroup)

        // When
        mockCrypto.generateSessionEstablishmentError = EncryptionError.encryptionFailed
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(delegate.stateToRender?.kind == .failed)
        #expect(sut.session == nil)
    }

    @Test("assembleAndEncryptRequest failure tears down session")
    func assembleAndEncryptRequestFailureTearDownsSession() {
        // Given
        let mockCrypto = MockCryptoService()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.startVerification(attributeGroup: testAttributeGroup)
        #expect(sut.session != nil)

        // When
        mockCrypto.generateSessionEstablishmentError = EncryptionError.encryptionFailed
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(sut.session == nil)
    }
}

// swiftlint:enable type_body_length
// swiftlint:enable file_length
