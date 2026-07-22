import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

// MARK: - HolderSession Tests

// swiftlint:disable type_body_length
// swiftlint:disable file_length
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
        try session.transition(to: .awaitingUserConsent(try createMockDeviceRequest()))
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

    @Test("SessionError is Equatable")
    func sessionErrorIsEquatable() {
        #expect(
            SessionError.unknown ==
            SessionError.unknown
        )
    }

    @Test(
        "HolderSessionState maps to correct HolderSessionStateKind",
        arguments: zip(
            [
                HolderSessionState.notStarted,
                .preflight(missingPrerequisites: []),
                .readyToPresent,
                .presentingEngagement(qrCode: UIImage()),
                .processingEstablishment,
                .processingResponse,
                .awaitingVerifierResolution,
                .success(reason: .responseSent),
                .success(reason: .denialResponse),
                .success(reason: .emptyResponse),
                .failed(SessionError.unknown),
                .cancelled
            ] as [HolderSessionState],
            [
                HolderSessionStateKind.notStarted,
                .preflight,
                .readyToPresent,
                .presentingEngagement,
                .processingEstablishment,
                .processingResponse,
                .awaitingVerifierResolution,
                .success,
                .success,
                .success,
                .failed,
                .cancelled
            ] as [HolderSessionStateKind]
        )
    )
    func holderSessionStateKindMapping(state: HolderSessionState, expectedKind: HolderSessionStateKind) {
        #expect(state.kind == expectedKind)
    }

    @Test("awaitingUserConsent maps to correct kind")
    func awaitingUserConsentKindMapping() throws {
        #expect(HolderSessionState.awaitingUserConsent(try createMockDeviceRequest()).kind == .awaitingUserConsent)
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
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session
                .setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
        }
        #expect(session.cryptoContext == nil)
        #expect(session.qrCode == nil)
    }
    
    @Test("setSKDeviceKey sets skDeviceKey when called")
    func setSKDeviceKeySetsSKDeviceKey() throws {
        // Given
        let session = HolderSession()
        #expect(session.cryptoContext?.skDeviceKey == nil)
        
        let serviceUUID = UUID()
        // swiftlint:disable:next line_length
        let mockDeviceEngagement = try DeviceEngagement(from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk")
        let cryptoContext = CryptoContext(serviceUUID: serviceUUID, deviceEngagement: mockDeviceEngagement)
        let qrCode = UIImage()
        
        session.currentState = .readyToPresent
        try session.setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
        
        let mockSKDeviceKey: [UInt8] = [01, 02]
        
        // When
        session.currentState = .processingEstablishment
        
        try session.setSKDeviceKey(mockSKDeviceKey)
        
        // Then
        #expect(session.cryptoContext?.skDeviceKey == mockSKDeviceKey)
    }
    
    @Test("setSKDeviceKey throws error when in invalid state")
    func setSKDeviceKeyThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.cryptoContext?.skDeviceKey == nil)
        let mockSKDeviceKey: [UInt8] = [01, 02]
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session
                .setSKDeviceKey(mockSKDeviceKey)
        }
        #expect(session.cryptoContext?.skDeviceKey == nil)
    }
    
    @Test("setSessionTranscriptAndDocType sets values in processingEstablishment state")
    func setSessionTranscriptAndDocTypeSetsValues() throws {
        // Given
        let session = HolderSession()

        // When
        session.currentState = .processingEstablishment
        
        try session.setSessionTranscriptAndDocType(
            sessionTranscript: SessionTranscript(
                deviceEngagementBytes: [0x01],
                eReaderKeyBytes: [0x02],
                handover: .qr
            ),
            docType: .mdl
        )
        
        // Then
        #expect(session.sessionTranscript != nil)
        #expect(session.docType == .mdl)
    }

    @Test("setSessionTranscriptAndDocType throws error when in invalid state")
    func setSessionTranscriptAndDocTypeThrowsError() throws {
        // Given
        let session = HolderSession()
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setSessionTranscriptAndDocType(
                sessionTranscript: SessionTranscript(
                    deviceEngagementBytes: [0x01],
                    eReaderKeyBytes: [0x02],
                    handover: .qr
                ),
                docType: .mdl
            )
        }
        #expect(session.sessionTranscript == nil)
        #expect(session.docType == nil)
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
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setConnection(connectionHandle)
        }
        #expect(session.connectionHandle == nil)
    }
    
    @Test("setMatchedCredential sets relevant field on session")
    func setMatchedCredentialSetsField() throws {
        // Given
        let session = HolderSession()
        #expect(session.matchedCredential == nil)
        
        let credential = Credential(id: "test", rawCredential: Data())
        
        session.currentState = .processingEstablishment
        
        // When
        try session.setMatchedCredential(credential)
        
        // Then
        #expect(session.matchedCredential?.id == credential.id)
    }
    
    @Test("setMatchedCredential throws error when in invalid state")
    func setMatchedCredentialThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.matchedCredential == nil)
        
        let credential = Credential(id: "test", rawCredential: Data())
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setMatchedCredential(credential)
        }
        #expect(session.matchedCredential == nil)
    }
    
    @Test("setIssuerSigned sets relevant field on session")
    func setIssuerSignedSetsField() throws {
        // Given
        let session = HolderSession()
        #expect(session.issuerSigned == nil)
        
        let issuerSigned = IssuerSigned(
            nameSpaces: ["Test": [IssuerSignedItem(
                digestID: 0,
                random: [1, 2],
                elementIdentifier: "test",
                elementValue: .utf8String("Test")
            )]],
            issuerAuth: [1, 2]
        )
        
        session.currentState = .processingEstablishment
        
        // When
        try session.setIssuerSigned(issuerSigned)
        
        // Then
        #expect(session.issuerSigned == issuerSigned)
    }
    
    @Test("setIssuerSigned throws error when in invalid state")
    func setIssuerSignedThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.issuerSigned == nil)
        
        let issuerSigned = IssuerSigned(
            nameSpaces: ["Test": [IssuerSignedItem(
                digestID: 0,
                random: [1, 2],
                elementIdentifier: "test",
                elementValue: .utf8String("Test")
            )]],
            issuerAuth: [1, 2]
        )
        
        // When
        session.currentState = .notStarted
        
        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setIssuerSigned(issuerSigned)
        }
        #expect(session.issuerSigned == nil)
    }

    @Test("setDeviceSigned sets relevant field on session")
    func setDeviceSignedSetsField() throws {
        // Given
        let session = HolderSession()
        #expect(session.deviceSigned == nil)

        let deviceSigned = DeviceSigned(
            nameSpaces: [],
            deviceAuth: DeviceAuth(deviceSignature: .null)
        )

        session.currentState = .processingResponse

        // When
        try session.setDeviceSigned(deviceSigned: deviceSigned)

        // Then
        #expect(session.deviceSigned == deviceSigned)
    }

    @Test("setDeviceSigned throws error when in invalid state")
    func setDeviceSignedThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.deviceSigned == nil)

        let deviceSigned = DeviceSigned(
            nameSpaces: [],
            deviceAuth: DeviceAuth(deviceSignature: .null)
        )

        session.currentState = .notStarted

        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setDeviceSigned(deviceSigned: deviceSigned)
        }
        #expect(session.deviceSigned == nil)
    }

    @Test("setDeviceAuthenticationBytes sets relevant field on session")
    func setDeviceAuthenticationBytesSetsField() throws {
        // Given
        let session = HolderSession()
        #expect(session.deviceAuthenticationBytes == nil)

        session.currentState = .processingResponse

        // When
        try session.setDeviceAuthenticationBytes(Data([0x01, 0x02]))

        // Then
        #expect(session.deviceAuthenticationBytes == Data([0x01, 0x02]))
    }

    @Test("setDeviceAuthenticationBytes throws error when in invalid state")
    func setDeviceAuthenticationBytesThrowsError() throws {
        // Given
        let session = HolderSession()
        #expect(session.deviceAuthenticationBytes == nil)

        session.currentState = .notStarted

        // Then
        #expect(
            throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
        ) {
            try session.setDeviceAuthenticationBytes(Data([0x01]))
        }
        #expect(session.deviceAuthenticationBytes == nil)
    }
}
// swiftlint:enable type_body_length

private func createMockDeviceRequest() throws -> DeviceRequest {
    // swiftlint:disable:next line_length
    let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
    return try DeviceRequest(data: Data(base64URLEncoded: cbor)!)
}

// MARK: - setDeviceResponse Tests

@Test("setDeviceResponse sets field when in processingEstablishment")
func setDeviceResponseSetsFieldInProcessingEstablishment() throws {
    // Given
    let session = HolderSession()
    session.currentState = .processingEstablishment
    let response = DeviceResponse(documents: nil, status: .ok)

    // When
    try session.setDeviceResponse(response)

    // Then
    #expect(session.deviceResponse == response)
}

@Test("setDeviceResponse sets field when in processingResponse")
func setDeviceResponseSetsFieldInProcessingResponse() throws {
    // Given
    let session = HolderSession()
    session.currentState = .processingResponse
    let response = DeviceResponse(documents: nil, status: .ok)

    // When
    try session.setDeviceResponse(response)

    // Then
    #expect(session.deviceResponse == response)
}

@Test("setDeviceResponse throws error when in invalid state")
func setDeviceResponseThrowsError() throws {
    // Given
    let session = HolderSession()
    session.currentState = .notStarted
    let response = DeviceResponse(documents: nil, status: .ok)

    // Then
    #expect(
        throws: SessionError.incorrectSessionState(session.currentState.kind.rawValue)
    ) {
        try session.setDeviceResponse(response)
    }
}
