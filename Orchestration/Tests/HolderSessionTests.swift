import CryptoService
@testable import Orchestration
import Testing
import UIKit

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
        try session.transition(to: .presentingEngagement(qrCode: UIImage()))
        try session.transition(to: .processingEstablishment)
        try session.transition(to: .requestReceived)
        try session.transition(to: .processingResponse)
        try session.transition(to: .complete(.cancelled))
    }

    // MARK: - Invalid Transitions

    @Test("Invalid transition throws HolderSessionTransitionError")
    func invalidTransitionThrows() async {
        let session = HolderSession(.notStarted)

        #expect(throws: HolderSessionTransitionError.self) {
            try session.transition(to: .processingEstablishment)
        }
    }

    @Test("ProcessingResponse cannot transition backwards")
    func processingResponseCannotTransitionBackwards() async {
        let session = HolderSession(.processingResponse)

        await #expect(
            throws: HolderSessionTransitionError.invalidTransition(
                from: .processingResponse,
                to: .processingEstablishment
            )
        ) {
            try session.transition(to: .processingEstablishment)
        }
    }

    // MARK: - State machine tests

    @Test("Valid transition updates currentState")
    func transitionUpdatesCurrentState() async throws {
        let session = HolderSession()

        #expect(session.currentState == .notStarted)

        try session.transition(to: .preflight(missingPermissions: []))

        #expect(session.currentState == .preflight(missingPermissions: []))
    }

    @Test("State machine does not emit on invalid transition")
    func stateMachineDoesNotEmitOnInvalidTransition() async {
        let session = HolderSession()

        #expect(session.currentState == .notStarted)
        #expect(throws: HolderSessionTransitionError.self) {
            try session.transition(to: .processingEstablishment)
        }
        #expect(session.currentState == .notStarted)
    }

    // MARK: - Completion/Terminal state tests

    @Test("Completion reason for success, and that it is Equatable")
    func completionReasonSuccess() {
        let completion = Completion.success(
            DeviceResponse(response: "OK")
        )
        #expect(completion.reason == "Session completed successfully")

        let completion2 = Completion.success(
            DeviceResponse(response: "OK")
        )
        #expect(completion == completion2)
    }

    @Test("Completion reason for failure")
    func completionReasonFailure() {
        let error = SessionError(message: "Failure")
        let completion = Completion.failed(error)

        #expect(completion.reason == "Failure")
    }

    @Test("Completion reason for cancellation")
    func completionReasonCancelled() {
        #expect(
            Completion.cancelled.reason ==
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
        let a = HolderSessionState.preflight(missingPermissions: [.bluetooth()])
        let b = HolderSessionState.preflight(missingPermissions: [.bluetooth()])

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

    @Test("All HolderSessionStateKinds are mapped correctly")
    func holderSessionStateKindMapping() {
        #expect(HolderSessionState.notStarted.kind == .notStarted)
        #expect(HolderSessionState.preflight(missingPermissions: []).kind == .preflight)
        #expect(HolderSessionState.readyToPresent.kind == .readyToPresent)
        #expect(HolderSessionState.presentingEngagement(qrCode: UIImage()).kind == .presentingEngagement)
        #expect(HolderSessionState.processingEstablishment.kind == .processingEstablishment)
        #expect(HolderSessionState.requestReceived.kind == .requestReceived)
        #expect(HolderSessionState.processingResponse.kind == .processingResponse)
        #expect(HolderSessionState.complete(.cancelled).kind == .complete)
    }

    @Test("Complete state has no legal transitions")
    func completeStateHasNoLegalTransitions() {
        let state = HolderSessionState.complete(.cancelled)

        #expect(
            state.legalStateTransitions[state.kind] == []
        )
    }

    @Test("Unknown transition kind lookup returns false")
    func canTransitionReturnsFalseWhenNoEntryExists() {
        let state = HolderSessionState.notStarted
        let result = state.legalStateTransitions[.complete]?.contains(.notStarted)
        #expect(result != nil)
        #expect(result == false)
    }

    @Test("HolderSessionState is Hashable")
    func holderSessionStateIsHashable() {
        let set: Set<HolderSessionState> = [
            .notStarted,
            .preflight(missingPermissions: [])
        ]

        #expect(set.contains(.notStarted))
    }

    @Test("Completion is Hashable")
    func completionIsHashable() {
        let set: Set<Completion> = [
            .cancelled,
            .success(DeviceResponse(response: "OK"))
        ]

        #expect(set.contains(.cancelled))
    }

    @Test("SessionError conforms to Error")
    func sessionErrorConformsToError() {
        let error: Error = SessionError(message: "Oops")

        #expect(error is SessionError)
    }
    
    // MARK: - Session Delegate Tests
    @Test("setEngagement sets relevant fields on session")
    func setEngagementSetsFields() throws {
        // Given
        let session = HolderSession()
        #expect(session.cryptoContext == nil)
        #expect(session.qrCode == nil)
        
        let serviceUUID = UUID()
        // swiftlint:disable:next line_length
        let mockDeviceEngagement = try DeviceEngagement(from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk")
        let cryptoContext = CryptoContext(serviceUUID: serviceUUID, deviceEngagement: mockDeviceEngagement)
        let qrCode = UIImage()
        
        session.currentState = .readyToPresent
        
        // When
        try session.setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
        
        // Then
        #expect(session.cryptoContext?.serviceUUID == cryptoContext.serviceUUID)
        #expect(session.cryptoContext?.deviceEngagement.toCBOR() == cryptoContext.deviceEngagement.toCBOR())
        #expect(session.qrCode == qrCode)
    }
    
    @Test("setEngagement sets throws error when in invalid state")
    func setEngagementThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.cryptoContext == nil)
        #expect(session.qrCode == nil)
        
        let serviceUUID = UUID()
        // swiftlint:disable:next line_length
        let mockDeviceEngagement = try DeviceEngagement(from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk")
        let cryptoContext = CryptoContext(serviceUUID: serviceUUID, deviceEngagement: mockDeviceEngagement)
        let qrCode = UIImage()
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: HolderSessionTransitionError
                .invalidTransition(from: session.currentState)
        ) {
            try session
                .setEngagement(crytoContext: cryptoContext, qrCode: qrCode)
        }
        #expect(session.cryptoContext == nil)
        #expect(session.qrCode == nil)
    }
    
    @Test("setConnection sets relevant fields on session")
    func setConnectionSetsFields() throws {
        // Given
        let session = HolderSession()
        #expect(session.serviceUUID == nil)
        
        let serviceUUID = UUID()
        
        session.currentState = .readyToPresent
        
        // When
        try session.setConnection(serviceUUID: serviceUUID)
        
        // Then
        #expect(session.serviceUUID == serviceUUID)
    }
    
    @Test("setConnection throws error when in invalid state")
    func setConnectionThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.serviceUUID == nil)
        
        let serviceUUID = UUID()
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(throws: HolderSessionTransitionError.invalidTransition(
            from: session.currentState
        )) {
            try session.setConnection(serviceUUID: serviceUUID)
        }
        #expect(session.serviceUUID == nil)
    }
}
