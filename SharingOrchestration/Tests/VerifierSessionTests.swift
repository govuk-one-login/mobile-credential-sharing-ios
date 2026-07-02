import SharingBluetoothTransport
import SharingCryptoService
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

    // MARK: - setEngagement Tests

    @Test("setEngagement succeeds when session is in processingEngagement state")
    func setEngagementSucceedsInProcessingEngagement() throws {
        let session = VerifierSession(.processingEngagement)
        let engagement = try DeviceEngagement(
            from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        )
        let cryptoContext = CryptoContext(deviceEngagement: engagement)

        try session.setEngagement(cryptoContext: cryptoContext)

        #expect(session.cryptoContext != nil)
    }

    @Test("setEngagement throws when session is not in processingEngagement state")
    func setEngagementThrowsInWrongState() throws {
        let session = VerifierSession(.readyToScan)
        let engagement = try DeviceEngagement(
            from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        )
        let cryptoContext = CryptoContext(deviceEngagement: engagement)

        #expect(throws: SessionError.self) {
            try session.setEngagement(cryptoContext: cryptoContext)
        }
    }

    // MARK: - setConnection Tests

    @Test("setConnection succeeds when session is in connecting state")
    func setConnectionSucceedsInConnecting() throws {
        let session = VerifierSession(.connecting)
        let connectionHandle = ConnectionHandle()

        try session.setConnection(connectionHandle)

        #expect(session.connectionHandle === connectionHandle)
    }

    @Test("setConnection throws when session is not in connecting state")
    func setConnectionThrowsInWrongState() {
        let session = VerifierSession(.processingEngagement)
        let connectionHandle = ConnectionHandle()

        #expect(throws: SessionError.self) {
            try session.setConnection(connectionHandle)
        }
    }

    // MARK: - setSessionKeys Tests

    @Test("setSessionKeys succeeds when session is in processingEngagement state")
    func setSessionKeysSucceedsInProcessingEngagement() throws {
        let session = VerifierSession(.processingEngagement)
        let engagement = try DeviceEngagement(
            from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        )
        try session.setEngagement(cryptoContext: CryptoContext(deviceEngagement: engagement))

        let skReader = [UInt8](repeating: 0xAA, count: 32)
        let skDevice = [UInt8](repeating: 0xBB, count: 32)
        try session.setSessionKeys(skReaderKey: skReader, skDeviceKey: skDevice)

        #expect(session.cryptoContext?.skReaderKey == skReader)
        #expect(session.cryptoContext?.skDeviceKey == skDevice)
    }

    @Test("setSessionKeys throws when session is not in processingEngagement state")
    func setSessionKeysThrowsInWrongState() throws {
        let session = VerifierSession(.processingEngagement)
        let engagement = try DeviceEngagement(
            from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        )
        try session.setEngagement(cryptoContext: CryptoContext(deviceEngagement: engagement))
        try session.transition(to: .connecting)

        #expect(throws: SessionError.self) {
            try session.setSessionKeys(
                skReaderKey: [UInt8](repeating: 0xAA, count: 32),
                skDeviceKey: [UInt8](repeating: 0xBB, count: 32)
            )
        }
    }

    // MARK: - setDocRequest Tests

    @Test("setDocRequest succeeds when session is in notStarted state")
    func setDocRequestSucceedsInNotStarted() throws {
        let session = VerifierSession()
        let docRequest = DocRequest(
            with: try #require(
                AttributeGroup(
                    mdlAttributes: [
                        .init(attribute: .portrait, intentToRetain: false)
                    ]
                )
            )
        )

        try session.setDocRequest(docRequest)

        #expect(session.docRequest == docRequest)
    }

    @Test("setDocRequest throws when session is not in notStarted state")
    func setDocRequestThrowsInWrongState() throws {
        let session = VerifierSession(.readyToScan)
        let docRequest = DocRequest(
            with: try #require(
                AttributeGroup(
                    mdlAttributes: [
                        .init(attribute: .portrait, intentToRetain: false)
                    ]
                )
            )
        )

        #expect(throws: SessionError.incorrectSessionState("readyToScan")) {
            try session.setDocRequest(docRequest)
        }
    }
}
