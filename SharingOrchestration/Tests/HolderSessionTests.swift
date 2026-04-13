import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
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
        try session.transition(to: .preflight(missingPrerequisites: []))
        try session.transition(to: .readyToPresent)
        try session.transition(to: .presentingEngagement(qrCode: UIImage()))
        try session.transition(to: .processingEstablishment)
        try session.transition(to: .requestReceived(try createMockDeviceRequest()))
        try session.transition(to: .processingResponse)
        try session.transition(to: .failed(.unknown))
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

        try session.transition(to: .preflight(missingPrerequisites: []))

        #expect(session.currentState == .preflight(missingPrerequisites: []))
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

    // MARK: - Equatable tests

    @Test("Transition error is Equatable")
    func transitionErrorIsEquatable() {
        let error1 = HolderSessionTransitionError.invalidTransition(
            from: .notStarted,
            to: .preflight(missingPrerequisites: [])
        )

        let error2 = HolderSessionTransitionError.invalidTransition(
            from: .notStarted,
            to: .preflight(missingPrerequisites: [])
        )

        #expect(error1 == error2)
    }

    @Test("HolderSessionState preflight is Equatable")
    func preflightStateIsEquatable() {
        let a = HolderSessionState.preflight(missingPrerequisites: [MissingPrerequisite.bluetooth(.authorizationNotDetermined)])
        let b = HolderSessionState.preflight(missingPrerequisites: [MissingPrerequisite.bluetooth(.authorizationNotDetermined)])

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
            SessionError.unknown ==
            SessionError.unknown
        )
    }

    @Test("All HolderSessionStateKinds are mapped correctly")
    func holderSessionStateKindMapping() throws {
        #expect(HolderSessionState.notStarted.kind == .notStarted)
        #expect(HolderSessionState.preflight(missingPrerequisites: []).kind == .preflight)
        #expect(HolderSessionState.readyToPresent.kind == .readyToPresent)
        #expect(HolderSessionState.presentingEngagement(qrCode: UIImage()).kind == .presentingEngagement)
        #expect(HolderSessionState.processingEstablishment.kind == .processingEstablishment)
        #expect(HolderSessionState.requestReceived(try createMockDeviceRequest()).kind == .requestReceived)
        #expect(HolderSessionState.processingResponse.kind == .processingResponse)
        #expect(HolderSessionState.success(DeviceResponse(response: "Test")).kind == .success)
        #expect(HolderSessionState.failed(SessionError.unknown).kind == .failed)
        #expect(HolderSessionState.cancelled.kind == .cancelled)
    }

    @Test("Complete state has no legal transitions")
    func completeStateHasNoLegalTransitions() {
        let state = HolderSessionState.failed(.unrecoverablePrerequisite(.bluetooth(.statePoweredOff)))

        #expect(
            state.legalStateTransitions[state.kind] == []
        )
    }

    @Test("Unknown transition kind lookup returns false")
    func canTransitionReturnsFalseWhenNoEntryExists() {
        let state = HolderSessionState.notStarted
        let result = state.legalStateTransitions[.processingEstablishment]?.contains(.notStarted)
        #expect(result != nil)
        #expect(result == false)
    }

    @Test("HolderSessionState is Hashable")
    func holderSessionStateIsHashable() {
        let set: Set<HolderSessionState> = [
            .notStarted,
            .preflight(missingPrerequisites: [])
        ]

        #expect(set.contains(.notStarted))
    }

    @Test("SessionError conforms to Error")
    func sessionErrorConformsToError() {
        let error: Error = SessionError.unknown

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
        #expect(session.serviceUUID == serviceUUID)
    }
    
    @Test("setEngagement throws error when in invalid state")
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
                .setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
        }
        #expect(session.cryptoContext == nil)
        #expect(session.qrCode == nil)
    }
    
    @Test("setConnection sets relevant fields on session")
    func setConnectionSetsFields() throws {
        // Given
        let session = HolderSession()
        #expect(session.connectionHandle == nil)
        
        let connectionHandle = ConnectionHandle(blePeripheralTransport: MockBlePeripheralTransport())
        
        session.currentState = .readyToPresent
        
        // When
        try session.setConnection(connectionHandle)
        
        // Then
        #expect(session.connectionHandle != nil)
    }
    
    @Test("setConnection throws error when in invalid state")
    func setConnectionThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.connectionHandle == nil)
        
        let connectionHandle = ConnectionHandle(blePeripheralTransport: MockBlePeripheralTransport())
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: HolderSessionTransitionError
                .invalidTransition(from: session.currentState)
        ) {
            try session.setConnection(connectionHandle)
        }
        #expect(session.connectionHandle == nil)
    }
}

private func createMockDeviceRequest() throws -> DeviceRequest {
    // swiftlint:disable:next line_length
    let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
    return try DeviceRequest(data: Data(base64URLEncoded: cbor)!)
}
