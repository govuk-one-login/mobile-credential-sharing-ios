@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing

@Suite("VerifierOrchestrator Tests")
struct VerifierOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var sut: VerifierOrchestrator

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

    @Test("startVerification evaluates the bluetooth prerequisite through the gate")
    func startVerificationEvaluatesBluetoothPrerequisite() {
        // Given
        mockPrerequisiteGate.notAllowedPrerequisites = []

        // When
        sut.startVerification()

        // Then
        #expect(sut.session?.currentState == .readyToScan)
    }

    @Test("A recoverable missing prerequisite transitions to preflight")
    func recoverableMissingPrerequisiteExposesPreflight() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.notAllowedPrerequisites = [.bluetooth(.authorizationNotDetermined)]

        // When
        sut.startVerification()

        // Then
        #expect(sut.session?.currentState == .preflight(missingPrerequisites: [.bluetooth(.authorizationNotDetermined)]))
        #expect(delegate.stateToRender == .preflight(missingPrerequisites: [.bluetooth(.authorizationNotDetermined)]))
    }

    @Test("resolve triggers triggerResolution on PrerequisiteGate")
    func resolveTriggersPRGateFunc() {
        // Given
        #expect(mockPrerequisiteGate.didCallTriggerResolution == false)

        // When
        sut.resolve(.bluetooth(.authorizationNotDetermined))

        // Then
        #expect(mockPrerequisiteGate.didCallTriggerResolution == true)
    }

    @Test("No missing prerequisites transitions to readyToScan")
    func noMissingPrerequisitesExposesReadyToScan() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.notAllowedPrerequisites = []

        // When
        sut.startVerification()

        // Then
        #expect(sut.session?.currentState == .readyToScan)
        #expect(delegate.stateToRender == .readyToScan)
    }

    @Test("An unrecoverable missing prerequisite fails the journey (denied)")
    func unrecoverablePrerequisiteDeniedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.notAllowedPrerequisites = [.bluetooth(.authorizationDenied)]

        // When
        sut.startVerification()

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.bluetooth(.authorizationDenied))))
    }

    @Test("An unrecoverable missing prerequisite fails the journey (restricted)")
    func unrecoverablePrerequisiteRestrictedFailsJourney() {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate
        mockPrerequisiteGate.notAllowedPrerequisites = [.bluetooth(.authorizationRestricted)]

        // When
        sut.startVerification()

        // Then
        #expect(delegate.stateToRender == .failed(.unrecoverablePrerequisite(.bluetooth(.authorizationRestricted))))
    }

    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given
        let delegate = MockVerifierOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedPrerequisites = []
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
}
