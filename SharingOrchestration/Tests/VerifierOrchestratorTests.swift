@testable import SharingOrchestration
import Testing

@Suite("VerifierOrchestrator Tests")
struct VerifierOrchestratorTests {
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
    func startAfterCancelCreatesNewSession() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification()
        sut.cancelVerification()
        #expect(sut.session == nil)

        // When
        sut.startVerification()

        // Then
        #expect(sut.session != nil)
    }

    @Test("Verifier session can represent notStarted and cancelled")
    func sessionRepresentsCanonicalStates() {
        // Given
        let sut = VerifierOrchestrator()
        sut.startVerification()
        let delegate = MockVerifierOrchestratorDelegate()
        sut.delegate = delegate

        // Then — session starts in notStarted
        #expect(sut.session?.currentState == .notStarted)

        // When — host app cancels
        sut.cancelVerification()

        // Then — delegate observes cancelled
        #expect(delegate.stateToRender == .cancelled)
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
}
