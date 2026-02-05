@testable import Orchestration
import Testing

// MARK: - HolderSession Tests

@Suite("HolderSession State Machine Tests")
struct HolderSessionTests {

    // MARK: - Initial State

    @Test("Default initial state is .notStarted")
    func initialStateDefaultsToNotStarted() async {
        let session = HolderSession()
        #expect(session.currentState == .notStarted)
    }

    // MARK: - Valid Transitions

    @Test("Valid transitions do not throw")
    func validTransitionsDoNotThrow() async throws {
        let session = HolderSession()
        try session.transition(to: .preflight(missingPermissions: []))
        try session.transition(to: .readyToPresent)
        try session.transition(to: .presentingEngagement)
        try session.transition(to: .connecting)
        try session.transition(to: .requestReceived)
        try session.transition(to: .processingResponse)
        try session.transition(to: .complete(.cancelled))
    }

    // MARK: - Invalid Transitions

    @Test("Invalid transition throws HolderSessionTransitionError")
    func invalidTransitionThrows() async {
        let session = HolderSession(.notStarted)

        #expect(throws: HolderSessionTransitionError.self) {
            try session.transition(to: .readyToPresent)
        }
    }

    @Test("ProcessingResponse cannot transition backwards")
    func processingResponseCannotTransitionBackwards() async {
        let session = HolderSession(.processingResponse)

        await #expect(
            throws: HolderSessionTransitionError.invalidTransition(
                from: .processingResponse,
                to: .connecting
            )
        ) {
            try session.transition(to: .connecting)
        }
    }

    // MARK: - State machine tests

    @Test("State machine emits initial and transitioned states")
    func stateMachineEmitsOnValidTransition() async throws {
        let session = HolderSession()
        var receivedStates: [HolderSessionState] = []

        #expect(session.currentState == .notStarted)
        receivedStates.append(session.currentState)
        try session.transition(to: .preflight(missingPermissions: []))
        receivedStates.append(session.currentState)

        #expect(
            receivedStates == [.notStarted, .preflight(missingPermissions: [])]
        )
    }

    @Test("State machine does not emit on invalid transition")
    func stateMachineDoesNotEmitOnInvalidTransition() async {
        let session = HolderSession()

        #expect(session.currentState == .notStarted)
        #expect(throws: HolderSessionTransitionError.self) {
            try session.transition(to: .readyToPresent)
        }
        #expect(session.currentState == .notStarted)
    }

    // MARK: - Completion/Terminal state tests

    @Test("Completion reason for success")
    func completionReasonSuccess() {
        let completion = HolderSessionState.Completion.success(
            DeviceResponse(response: "OK")
        )

        #expect(completion.reason == "Session completed successfully")
    }

    @Test("Completion reason for failure")
    func completionReasonFailure() {
        let error = SessionError(message: "Failure")
        let completion = HolderSessionState.Completion.failed(error)

        #expect(completion.reason == "Failure")
    }

    @Test("Completion reason for cancellation")
    func completionReasonCancelled() {
        #expect(
            HolderSessionState.Completion.cancelled.reason ==
            "Session cancelled by User"
        )
    }

    // MARK: - Equatable tests

    @Test("Transition error is Equatable")
    func transitionErrorIsEquatable() {
        let error1 = HolderSessionTransitionError.invalidTransition(
            from: .notStarted,
            to: .preflight(missingPermissions: [])
        )

        let error2 = HolderSessionTransitionError.invalidTransition(
            from: .notStarted,
            to: .preflight(missingPermissions: [])
        )

        #expect(error1 == error2)
    }

    @Test("HolderSessionState preflight is Equatable")
    func preflightStateIsEquatable() {
        let a = HolderSessionState.preflight(missingPermissions: ["Camera"])
        let b = HolderSessionState.preflight(missingPermissions: ["Camera"])

        #expect(a == b)
    }

    @Test("DeviceResponse is Equatable")
    func deviceResponseIsEquatable() {
        #expect(
            DeviceResponse(response: "OK") ==
            DeviceResponse(response: "OK")
        )
    }

    @Test("SessionError is Equatable")
    func sessionErrorIsEquatable() {
        #expect(
            SessionError(message: "Error") ==
            SessionError(message: "Error")
        )
    }
}
