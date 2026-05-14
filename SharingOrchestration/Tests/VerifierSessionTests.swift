@testable import SharingOrchestration
import Testing

@Suite("VerifierSession State Machine Tests")
struct VerifierSessionTests {

    @Test("Default initial state is .notStarted")
    func initialStateDefaultsToNotStarted() {
        let session = VerifierSession()
        #expect(session.currentState == .notStarted)
    }

    @Test("Valid transition from notStarted to cancelled does not throw")
    func validTransitionDoesNotThrow() throws {
        let session = VerifierSession()
        try session.transition(to: .cancelled)
        #expect(session.currentState == .cancelled)
    }

    @Test("Invalid transition from cancelled throws VerifierSessionTransitionError")
    func invalidTransitionFromCancelledThrows() {
        let session = VerifierSession(.cancelled)

        #expect(throws: VerifierSessionTransitionError.self) {
            try session.transition(to: .notStarted)
        }
    }

    @Test("Cancelled state has no legal transitions")
    func cancelledHasNoLegalTransitions() {
        let session = VerifierSession(.cancelled)

        #expect(throws: VerifierSessionTransitionError.self) {
            try session.transition(to: .cancelled)
        }
    }

    @Test("State machine does not change state on invalid transition")
    func stateMachineDoesNotChangeOnInvalidTransition() {
        let session = VerifierSession(.cancelled)

        #expect(throws: VerifierSessionTransitionError.self) {
            try session.transition(to: .notStarted)
        }
        #expect(session.currentState == .cancelled)
    }

    @Test("VerifierSession is Equatable")
    func sessionIsEquatable() {
        #expect(VerifierSession(.notStarted) == VerifierSession(.notStarted))
    }

    @Test("Transition error is Equatable")
    func transitionErrorIsEquatable() {
        let error1 = VerifierSessionTransitionError.invalidTransition(from: .notStarted, to: .notStarted)
        let error2 = VerifierSessionTransitionError.invalidTransition(from: .notStarted, to: .notStarted)
        #expect(error1 == error2)
    }

    @Test("VerifierSessionState is Hashable")
    func stateIsHashable() {
        let set: Set<VerifierSessionState> = [.notStarted, .cancelled]
        #expect(set.count == 2)
    }

    @Test("All VerifierSessionStateKinds are mapped correctly and canTransition behaves correctly")
    func stateKindMappingAndTransitions() {
        #expect(VerifierSessionState.notStarted.kind == .notStarted)
        #expect(VerifierSessionState.cancelled.kind == .cancelled)
        #expect(VerifierSessionState.notStarted.canTransition(to: .cancelled) == true)
        #expect(VerifierSessionState.cancelled.canTransition(to: .notStarted) == false)
    }
}
