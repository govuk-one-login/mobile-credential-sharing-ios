import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing

// swiftlint:disable file_length
@MainActor
@Suite("VerifierOrchestrator Tests")
struct VerifierOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var sut: VerifierOrchestrator
    let missingPrerequisitesAllNotDetermined: [MissingPrerequisite] = [
        .camera(.authorizationNotDetermined),
        .bluetooth(.authorizationNotDetermined)
    ]

    init() {
        sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate)
    }

    @Test("startVerification creates a new VerifierSession")
    func startVerificationCreatesSession() {
        // Given
        let sut = VerifierOrchestrator()
        #expect(sut.session == nil)

        // When
        sut.startVerification()

        // Then
        #expect(sut.session != nil)
    }

    @Test("cancelVerification releases the session")
    func cancelVerificationReleasesSession() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification()
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
        sut.startVerification()

        // When
        sut.cancelVerification()

        // Then
        #expect(delegate.stateToRender == .cancelled)
    }

    @Test("startVerification after cancel creates a new session instance")
    func startAfterCancelCreatesNewSession() throws {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification()

        let firstSession = try #require(sut.session as? VerifierSession)

        // When
        sut.cancelVerification()
        sut.startVerification()

        let secondSession = try #require(sut.session as? VerifierSession)

        // Then
        #expect(firstSession !== secondSession)
    }

    @Test("cancelVerification on already cancelled session still releases")
    func cancelOnAlreadyCancelledStillReleases() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification()
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
        sut.startVerification()

        // Then
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.camera))
        #expect(mockPrerequisiteGate.evaluatedPrerequisites.contains(.bluetooth))
    }

    @Test("startVerification evaluates the bluetooth prerequisite through the gate")
    func startVerificationEvaluatesBluetoothPrerequisite() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []

        // When
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        
        sut.startVerification()
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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

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
        sut.startVerification()

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.camera(.stateUnsupported))))
    }

    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.delegate = delegate
        sut.startVerification()

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
        sut.startVerification()
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
        sut.startVerification()

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then
        #expect(sut.session?.currentState == .connecting)
        #expect(delegate.stateToRender == .connecting)
    }

    @Test("Non-mdoc QR code transitions session to failed")
    func malformedMdocQRTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification()

        // When
        mockCrypto.processQRCodeError = CryptoServiceError.nonMdocQRScanned
        sut.qrCodeScanned("no-mdoc-prefix")

        // Then
        #expect(sut.session?.currentState.kind == .failed)
        #expect(delegate.stateToRender?.kind == .failed)
    }

    @Test("Malformed mdoc QR code transitions session to failed")
    func nonMdocQRTransitionsToFailed() {
        // Given
        let mockCrypto = MockCryptoService()
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let sut = VerifierOrchestrator(prerequisiteGate: mockPrerequisiteGate, cryptoService: mockCrypto)
        sut.delegate = delegate
        sut.startVerification()

        // When
        mockCrypto.processQRCodeError = DeviceEngagementError.requestWasIncorrectlyStructured
        sut.qrCodeScanned("mdoc:invalid")

        // Then
        #expect(sut.session?.currentState.kind == .failed)
        #expect(delegate.stateToRender?.kind == .failed)
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
        sut.startVerification()

        // When
        sut.qrCodeScanned("mdoc:validEngagementData")

        // Then - processingEngagement is emitted before connecting
        #expect(delegate.statesReceived.contains(.processingEngagement))
        #expect(delegate.statesReceived.contains(.connecting))
        let processingIndex = delegate.statesReceived.firstIndex(of: .processingEngagement)
        let connectingIndex = delegate.statesReceived.firstIndex(of: .connecting)
        #expect(try #require(processingIndex) < #require(connectingIndex))
    }
}
// swiftlint:enable file_length
