import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import SwiftCBOR
import Testing
import UIKit

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@MainActor
@Suite("BLEHolderOrchestrator Tests")
struct ISOHolderOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var mockBluetoothTransport = MockBluetoothTransport()
    var mockCryptoService = MockCryptoService()
    var mockCredentialRequestHandler = MockCredentialRequestHandler()
    var sut: ISOHolderOrchestrator
    
    init() {
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            credentialRequestHandler: mockCredentialRequestHandler
        )
    }
    
    @Test("start creates a new BLEHolderSession object")
    func startCreatesBLEHolderSession() {
        // Given
        #expect(sut.session == nil)
        
        // When
        sut.start()
        
        // Then
        #expect(sut.session != nil)
    }
    
    @Test("cancel sets the session & all packages to nil")
    mutating func cancelSetsSessionToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.start()

        #expect(sut.session != nil)
        #expect(sut.prerequisiteGate != nil)
        #expect(sut.cryptoService != nil)
        #expect(sut.bluetoothTransport != nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == false)
        
        // When
        sut.cancel()
        
        // Then
        #expect(sut.session == nil)
        #expect(sut.prerequisiteGate == nil)
        #expect(sut.cryptoService == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }
    
    @Test("start successfully transitions to .bleReadyToPresent when capabilities are allowed")
    func startProceedsToReadyToPresent() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        // When
        sut.start()
        
        // Then
        #expect(sut.session?.currentState == .isoReadyToPresent)
    }
    
    @Test("start successfully transitions to .preflight when capabilities are not allowed")
    func startProceedsToPreflight() {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationNotDetermined)]
        
        // When
        sut.start()
        
        // Then
        #expect(sut.session?.currentState == .preflight(missingPrerequisites: mockPrerequisiteGate.missingPrerequisitesToReturn))
    }
    
    @Test("resolve triggers triggerResolutionfunc on PrerequisiteGate")
    func resolveTriggersPRGateFunc() throws {
        // Given
        _ = try #require(sut.prerequisiteGate)
        #expect(mockPrerequisiteGate.didCallTriggerResolution == false)
        
        // When
        sut.resolve(MissingPrerequisite.bluetooth(.authorizationNotDetermined))
        
        // Then
        #expect(mockPrerequisiteGate.didCallTriggerResolution == true)
    }
    
    @Test("prepareEngagement transitions to .blePresentingEngagement state")
    mutating func didStartAdvertisingTransitionsToPresentingEngagement() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        // When
        /// With bluetoothTransport mocked, start will successfully proceed to prepareEngagement
        sut.start()
        
        // Then
        let qrCode = try #require(sut.session?.qrCode)
        #expect(sut.session?.currentState == .isoPresentingEngagement(qrCode: qrCode))
    }
    
    @Test("prepareEngagement renders error when session is nil")
    func prepareEngagementRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.prepareEngagement()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("prepareEngagement renders error when cryptoContext is nil")
    mutating func prepareEngagementRendersErrorContextNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.forceFailureWithInvalidData = true
        
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.start()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session engagement failed to prepare correctly.")))
    }
    
    @Test("presentQRCode renders error when qrCode on session is nil")
    mutating func presentQRCodeWhenNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        /// Public delegate function that calls private presentQRCode function
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("QR Code failed to generate.")))
    }
    
    @Test("connectionDidConnect transitions to .bleProcessingEstablishment state")
    mutating func connectionDidConnectTransitionsToProcessingEstablishment() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        // When
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(sut.session?.currentState == .isoProcessingEstablishment)
    }
    
    @Test("connectionDidConnect renders error when session is nil")
    func connectionDidConnectRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test(".didReceive calls cryptoService.processSessionEstablishment")
    mutating func didReceiveCallsCryptoServiceFunction() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        #expect(mockCryptoService.didCallProcessSessionEstablishment == false)
        #expect(mockCryptoService.incomingBytes == nil)
        #expect(mockCryptoService.passedSession == nil)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockCryptoService.didCallProcessSessionEstablishment == true)
        #expect(mockCryptoService.incomingBytes == data)
        // Checking the session matches by comparing the cryptoContext.serviceUUID
        #expect(mockCryptoService.passedSession?.cryptoContext?.serviceUUID == sut.session?.cryptoContext?.serviceUUID)
    }
    
    @Test(".didReceive transitions to requestReceived and renders state")
    mutating func didReceiveTransitionsToRequestReceivedAndRendersState() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()
        
        // Then
        #expect(sut.session?.currentState == .awaitingUserConsent(deviceRequest))
        #expect(mockDelegate.stateToRender == .awaitingUserConsent(deviceRequest))
    }
    
    @Test(".didReceive renders error when session is nil")
    func didReceiveRendersErrorSessionNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("bluetoothTransportDidFail renders error")
    func bluetoothTransportDidFailRendersError() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        let error = BluetoothTransportError.peripheral(.unknown)
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("An unknown error has occured.")))
    }
    
    @Test("cancelPresentation sets all services to nil")
    mutating func cancelPresentationSetsServicesToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        // When
        /// With bluetoothTransport mocked, start will successfully proceed to prepareEngagement
        sut.start()
        #expect(sut.session != nil)
        #expect(sut.prerequisiteGate != nil)
        #expect(sut.bluetoothTransport != nil)
        #expect(sut.cryptoService != nil)
        
        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(sut.session == nil)
        #expect(sut.prerequisiteGate == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(sut.cryptoService == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }
    
    @Test("performPreflightChecks renders error when bluetooth auth is denied")
    func preflightChecksDeniedRendersError() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationDenied)]
        sut.delegate = mockDelegate
        
        // When
        sut.start()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.unrecoverablePrerequisite(MissingPrerequisite.bluetooth(.authorizationDenied))))
    }
    
    @Test("performPreflightChecks renders error when bluetooth auth is restricted")
    func preflightChecksRestrictedRendersError() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = [MissingPrerequisite.bluetooth(.authorizationRestricted)]
        sut.delegate = mockDelegate
        
        // When
        sut.start()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.unrecoverablePrerequisite(MissingPrerequisite.bluetooth(.authorizationRestricted))))
    }
    
    @Test("didReceive renders error when processSessionEstablishment throws")
    mutating func didReceiveRendersErrorWhenProcessingThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        // When
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        // Invalid data will cause processSessionEstablishment to throw
        sut.bluetoothTransportDidReceiveMessageData(Data([0x00]))
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))
    }
    
    @Test("cancel renders cancelled state")
    func cancelRendersState() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.start()
        
        // When
        sut.cancel()
        
        // Then
        #expect(mockDelegate.stateToRender == .cancelled)
    }
    
    // MARK: - DeviceResponse tests
    @Test("assembleAndEncryptResponse builds empty DeviceResponse with error code 11 on DeviceRequest decode failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnDecodeFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        let sessionData = SessionData(data: stubbedEncryptedResponse, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockCryptoService.passedDeviceResponse?.status == .cborDecodingError)
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("assembleAndEncryptResponse builds empty DeviceResponse with error code 12 on DeviceRequest validation failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnValidateFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        let invalidDeviceRequest = try #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4A"))

        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        let sessionData = SessionData(data: stubbedEncryptedResponse, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(invalidDeviceRequest)
        
        // Then
        #expect(mockCryptoService.passedDeviceResponse?.status == .cborValidationError)
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("assembleAndEncryptResponse builds SessionData model with no DeviceResponse on generic didReceive failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnGenericRequessFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        let sessionData = SessionData(data: nil, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        mockCryptoService.proccessSessionEstablishmentShouldThrow = true
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    @Test("assembleAndEncryptResponse builds SessionData model with no DeviceResponse on encryption failure")
    mutating func assembleAndEncryptResponseBuildsEmptyResponseOnEncryptionFailure() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        try session.setSessionTranscriptAndDocType(
            sessionTranscript: SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            ),
            docType: .mdl
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        
        let sessionData = SessionData(data: nil, status: .sessionTermination)
        let encodedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        // When
        mockCryptoService.encryptDeviceResponseError = .skDeviceKeyNotFound
        sut.assembleAndEncryptResponse()
        
        // Then
        #expect(mockBluetoothTransport.lastSentSessionData == encodedBytes)
    }
    
    // MARK: - DeviceAuthenticationBytes tests
    
    @Test("prepareDeviceSignedResponse renders error when session is nil")
    func constructDeviceAuthenticationBytesRendersErrorSessionNil() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        
        // When
        await sut.prepareDeviceSignedResponse()
        
        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }
    
    @Test("prepareDeviceSignedResponse triggers termination when constructDeviceAuthenticationBytes throws")
    mutating func constructDeviceAuthenticationBytesTriggersTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler,
        )
        sut.delegate = mockDelegate
        sut.start()
        
        // When
        mockCryptoService.constructDeviceAuthenticationBytesShouldThrow = true
        await sut.prepareDeviceSignedResponse()
        
        // Then
        let sessionData = SessionData(status: .sessionTermination)
        let expectedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        #expect(mockBluetoothTransport.lastSentSessionData == expectedBytes)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("prepareDeviceSignedResponse triggers termination when sign throws")
    mutating func generateDeviceSignedTriggersTerminationOnSignFailure() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.errorToThrow = CredentialRequestError.matchedCredentialNotFound
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler,
        )
        sut.delegate = mockDelegate
        sut.start()
        
        // When
        await sut.prepareDeviceSignedResponse()
        
        // Then
        let sessionData = SessionData(status: .sessionTermination)
        let expectedBytes = Data(sessionData.encode(options: CBOROptions()))
        
        #expect(mockBluetoothTransport.lastSentSessionData == expectedBytes)
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    @Test("prepareDeviceSignedResponse stores DeviceSigned with correct COSE_Sign1 structure on success")
    mutating func generateDeviceSignedStoresDeviceSignedOnSuccess() async throws {
        // Given
        let mockHandler = MockCredentialRequestHandler()
        mockHandler.stubbedSignatureBytes = Data([0xAA, 0xBB])
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockCryptoService.stubbedDeviceAuthenticationBytes = Data([0x01])

        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler,
        )
        
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        
        // Set matched credential
        let session = try #require(sut.session as? ISOHolderSession)
        try session.setMatchedCredential(Credential(id: "mock-id", rawCredential: Data()))

        // Transition to processingResponse (via awaitingUserConsent)
        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))
        try session.transition(to: .processingResponse)

        // When
        await sut.prepareDeviceSignedResponse()

        // Then - DeviceSigned is populated with untagged COSE_Sign1
        let deviceSigned = try #require(session.deviceSigned)

        let cbor = deviceSigned.toCBOR()
        guard case let .map(map) = cbor,
              case let .map(authMap) = map[.utf8String("deviceAuth")],
              case let .array(coseSign1) = authMap[.utf8String("deviceSignature")] else {
            Issue.record("Expected deviceAuth.deviceSignature COSE_Sign1 array")
            return
        }

        #expect(coseSign1.count == 4)
        // Protected header: {1: -7} (ES256)
        guard case let .byteString(protectedHeaderBytes) = coseSign1[0] else {
            Issue.record("Expected protected header as byteString")
            return
        }
        let decodedHeader = try CBOR.decode(protectedHeaderBytes)
        #expect(decodedHeader == .map([.unsignedInt(1): .negativeInt(6)]))
        // Unprotected header: empty map
        #expect(coseSign1[1] == .map([:]))
        // Payload: null
        #expect(coseSign1[2] == .null)
        // Signature: raw bytes from sign()
        #expect(coseSign1[3] == .byteString([0xAA, 0xBB]))
    }

    // MARK: - Catch block coverage tests
    
    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut.delegate = mockDelegate
        sut.start()
        
        // Force session into a terminal state so transition to .bleReadyToPresent throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.performPreflightChecks()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("prepareEngagement renders error when startAdvertising throws")
    mutating func prepareEngagementRendersErrorWhenStartAdvertisingThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        mockBluetoothTransport.shouldThrowOnStartAdvertising = true
        
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        // When
        sut.start()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("presentQRCode renders error when session transition to presentingEngagement throws")
    mutating func presentQRCodeRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        
        // start transitions through to .blePresentingEngagement
        sut.start()
        #expect(sut.session?.currentState.kind == .isoPresentingEngagement)
        
        // When — calling didStartAdvertising again tries to transition to .blePresentingEngagement from .blePresentingEngagement which is invalid
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("connectionDidConnect renders error when session transition throws")
    func connectionDidConnectRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.start()
        
        // Force session into a terminal state so transition to .bleProcessingEstablishment throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
    
    @Test("cancel renders error when session transition to cancelled throws")
    func cancelRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.start()
        
        // Force session into a terminal state so transition to .cancelled throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.cancel()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }

    @Test(".didReceive calls handleNoMatchTermination when credentialRequestHandler throws CredentialRequestError")
    mutating func didReceiveHandlesNoMatchTermination() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.errorToThrow = CredentialRequestError.noCredentialsReturned

        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
    }

    // MARK: - filterIssuerSigned tests

    @Test("filterIssuerSigned is called after successful credential validation")
    mutating func filterIssuerSignedCalledAfterValidation() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(mockHandler.didCallFilterIssuerSigned == true)
    }

    @Test("filterIssuerSigned transitions to awaitingUserConsent on success")
    mutating func filterIssuerSignedTransitionsToAwaitingUserConsent() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(sut.session?.currentState == .awaitingUserConsent(deviceRequest))
        #expect(mockDelegate.stateToRender == .awaitingUserConsent(deviceRequest))
    }

    @Test("filterIssuerSigned triggers No Match termination when filter throws noMatchingNameSpaces")
    mutating func filterIssuerSignedTriggersTerminationOnNoMatchingNameSpaces() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.noMatchingNameSpaces

        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
    }

    @Test("filterIssuerSigned triggers No Match termination when filter throws noMatchingAttributes")
    mutating func filterIssuerSignedTriggersTerminationOnNoMatchingAttributes() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.noMatchingAttributes

        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockHandler
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
    }

    // MARK: - DCMAW-18944: Consent Accept & Deny UI Logic
    @Test("Accept constructs DeviceResponse with documents and status 0, encrypts and wraps in SessionData with no status, transmits via BLE")
    mutating func acceptConstructsDeviceResponseWithDocumentsEncryptsAndTransmitsViaBLE() throws {
        // Given
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        try session.setSessionTranscriptAndDocType(
            sessionTranscript: SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            ),
            docType: .mdl
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        // When
        sut.assembleAndEncryptResponse()

        // Then - DeviceResponse has documents and status 0
        #expect(mockCryptoService.passedDeviceResponse?.documents != nil)
        #expect(mockCryptoService.passedDeviceResponse?.documents?.isEmpty == false)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)
        #expect(mockCryptoService.passedDeviceResponse?.version == "1.0")

        // Then - SessionData transmitted via BLE with no status code
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("data")] != nil)
        #expect(map[CBOR("status")] == nil)
    }

    @Test("After acceptance and BLE transmission, state tears down successfully")
    mutating func acceptTransitionsToSuccessAfterBLETransmission() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        try session.setSessionTranscriptAndDocType(
            sessionTranscript: SessionTranscript(
                deviceEngagementBytes: [0x00],
                eReaderKeyBytes: [0x00],
                handover: .qr
            ),
            docType: .mdl
        )
        try session.setIssuerSigned(IssuerSigned(nameSpaces: [:], issuerAuth: []))

        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))
        try session.transition(to: .processingResponse)
        try session.setDeviceSigned(deviceSigned: DeviceSigned(
            nameSpaces: CBOR.map([:]).encode(),
            deviceAuth: DeviceAuth(deviceSignature: .array([]))
        ))

        // When
        sut.assembleAndEncryptResponse()

        // Then
        // State transitions to .success
        #expect(mockDelegate.stateToRender?.kind == .success)
    }

    @Test("Deny constructs DeviceResponse with status 0, no documents, encrypts and wraps in SessionData with status 20, transmits via BLE")
    mutating func denyConstructsEmptyDeviceResponseEncryptsAndTransmitsWithStatus20() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        let stubbedEncryptedResponse = try #require(Data(base64Encoded: "TestData"))
        mockCryptoService.stubbedEncryptedResponse = stubbedEncryptedResponse
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))

        // When
        sut.userDidDeny()

        // Then - DeviceResponse has no documents and status 0
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .ok)

        // Then - SessionData transmitted via BLE with status 20
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        let sentData = try #require(mockBluetoothTransport.lastSentSessionData)
        let decoded = try #require(try CBOR.decode([UInt8](sentData)))
        guard case let .map(map) = decoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map[CBOR("status")] == .unsignedInt(20))
    }

    @Test("After denial and BLE transmission, state transitions to .cancelled")
    mutating func denyTransitionsToCancelledAfterBLETransmission() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))

        // When
        sut.userDidDeny()

        // Then - state transitions to .cancelled
        #expect(mockDelegate.stateToRender == .cancelled)
    }
    
    @Test("filterIssuerSigned terminates with DeviceResponse status 10 when exceededAgeOverLimit is thrown")
    mutating func filterIssuerSignedTerminatesWithGeneralErrorOnExceededAgeOverLimit() async throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWLqiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xqWtmYW1pbHlfbmFtZfRrYWdlX292ZXJfMTj0a2FnZV9vdmVyXzIx9GthZ2Vfb3Zlcl8xNvRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest

        let mockHandler = MockCredentialRequestHandler()
        mockHandler.filterErrorToThrow = IssuerSignedFilterError.exceededAgeOverLimit
        // swiftlint:disable:next line_length
        let rawCredential = Data(base64URLEncoded: "ompuYW1lU3BhY2VzonRvcmcuaXNvLjE4MDEzLjUuMS5HQoHYGFhRpGhkaWdlc3RJRAxxZWxlbWVudElkZW50aWZpZXJtd2Vsc2hfbGljZW5jZWZyYW5kb21QNQc4ty_4GCc5_X0FIxFf9WxlbGVtZW50VmFsdWX0cW9yZy5pc28uMTgwMTMuNS4xhtgYWFKkaGRpZ2VzdElECnFlbGVtZW50SWRlbnRpZmllcmtmYW1pbHlfbmFtZWZyYW5kb21QHPA1-aYTxYyXDpPga8JdgmxlbGVtZW50VmFsdWVjRG9l2BhYW6RoZGlnZXN0SUQJcWVsZW1lbnRJZGVudGlmaWVyamJpcnRoX2RhdGVmcmFuZG9tUO520QWmnv3ZKjodPtj4YTpsZWxlbWVudFZhbHVl2QPsajE5OTAtMDYtMTXYGFhPpGhkaWdlc3RJRAZxZWxlbWVudElkZW50aWZpZXJrYWdlX292ZXJfMThmcmFuZG9tUMXuD9q3H4Re9FXsw_N6iDJsZWxlbWVudFZhbHVl9dgYWE-kaGRpZ2VzdElECHFlbGVtZW50SWRlbnRpZmllcmthZ2Vfb3Zlcl8yMWZyYW5kb21QB4UsfF-gPnCpT1XhVwiRnGxlbGVtZW50VmFsdWX12BhYoqRoZGlnZXN0SUQAcWVsZW1lbnRJZGVudGlmaWVycmRyaXZpbmdfcHJpdmlsZWdlc2ZyYW5kb21QebAzXhYz5ZfawBzo-nLWd2xlbGVtZW50VmFsdWWBo3V2ZWhpY2xlX2NhdGVnb3J5X2NvZGVhQmppc3N1ZV9kYXRl2QPsajIwMjAtMDEtMDFrZXhwaXJ5X2RhdGXZA-xqMjAzMC0wMS0wMdgYWFykaGRpZ2VzdElEB3FlbGVtZW50SWRlbnRpZmllcnZ1bl9kaXN0aW5ndWlzaGluZ19zaWduZnJhbmRvbVB8_lE7s8kMzOkX2Pfxj_8-bGVsZW1lbnRWYWx1ZWJVS2ppc3N1ZXJBdXRohEOhASahGCFZAdYwggHSMIIBeaADAgECAhRNWsW03w4kSLcu-DByVtPa4cxbwDAKBggqhkjOPQQDAjA_MQswCQYDVQQGEwJVSzELMAkGA1UECAwCR0IxDTALBgNVBAoMBERWTEExFDASBgNVBAMMC2R2bGEuZ292LnVrMB4XDTI1MDYwNDE1MjAxN1oXDTI2MDYwNDE1MjAxN1owPzELMAkGA1UEBhMCVUsxCzAJBgNVBAgMAkdCMQ0wCwYDVQQKDAREVkxBMRQwEgYDVQQDDAtkdmxhLmdvdi51azBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABME7DvO4Tko41e6zPYSxAlcgKk7DClYytlbGUMb_pTWYfy_0sS1-abgnAxytgr0STRjX3_wVXhJtbJO6IpI1NJqjUzBRMB0GA1UdDgQWBBTQobpL3smcZBLCHdOb3Bx8wuhxqjAfBgNVHSMEGDAWgBTQobpL3smcZBLCHdOb3Bx8wuhxqjAPBgNVHRMBAf8EBTADAQH_MAoGCCqGSM49BAMCA0cAMEQCIGL4_6uPFvvNAoR_8vul6PPN9X7eubiAMUtqL8ZidJhbAiBFddvotS8QJrHUXS0ItWHbikowHHEduNPDoB5F1LtmwFkC-NgYWQLzpWd2ZXJzaW9uYzEuMG9kaWdlc3RBbGdvcml0aG1nU0hBLTI1Nmdkb2NUeXBldW9yZy5pc28uMTgwMTMuNS4xLm1ETGx2YWx1ZURpZ2VzdHOidG9yZy5pc28uMTgwMTMuNS4xLkdCoQxYIFfK7i-mXcn7zDaaMt3UwBlibwDuWI5yXNOIVjjKq4nVcW9yZy5pc28uMTgwMTMuNS4xrgFYIK_bpgqudgzuatHVcXiGKOnvkhQ2A5AvgdYKvIybvvTDClggVjoEqwVu_RPUy1Bw6hSggFEruyMbXxtainRi8uUzvLgJWCBT4r-uzM-x2LdRAfyEiGlH9CZx5aufBIrmQtDAn2iN6AZYIEVkz1OG8zqOuyS0oiXClRxHGwERHdnpXejeA4aILVrRCFggTVOp37d1Z8L6cPp7i30MxZzz1ef9rq5QXJes_EBRNg8CWCC5i-KQ2gPtfrqJzBn7Wa5RHpfan-FsQWHxGITimPuchgtYIIh8Fvqovz4DhT_G6X4ChPBnrBSCjoqLfWa8I7YVX_MtDlggfKvb4EsHzUqRyCvsrlebxaBAes5GJQxDzLpwr1_v7zgNWCCKgaDTbcLjttgtRo0GawJtiY7ZdvCrH_8Xx8gsufAYFQVYIGdJjomqXmlZcX8O_jTjlWEOQf5NbtiGfDIKV2lTFSl9BFggnHEfu8Ts7heL1CvgmNvJC5HTC2tpP6WQ-usfcN9pZRUDWCB7XkWTpcB61RaJS4RMRRrgbeeVNmLPUIQJNA5pvDvH1ABYILivJnFz2oHrps5F83OHUlbN6euCOll6Y8KbunPU1QIuB1ggB7SpkdOrsPrrPIkqyFVnFsOEPjEeCBkHlj8mfsitvwlsdmFsaWRpdHlJbmZvo2ZzaWduZWTAdDIwMjYtMDMtMTBUMTQ6MTk6MzNaaXZhbGlkRnJvbcB0MjAyNi0wMy0xMFQxNDoxOTozM1pqdmFsaWRVbnRpbMB0MjAyNy0wMy0xMFQxNDoxOTozM1pYQDixK8gqP2wizgyOpWaSv7G5tcKl5nJ7op-3i7naFLUX1QZsf2NXx-vUOpuwBa9kYIrhaLL0aqLh-xHZghS6AEk")
        let testCredentialProvider = TestCredentialProvider()
        testCredentialProvider.rawCredential = rawCredential
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: CredentialRequestHandler(credentialProvider: testCredentialProvider)
        )
        sut.delegate = mockDelegate

        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        await Task.yield()

        // Then
        #expect(mockBluetoothTransport.didCallSendSessionData == true)
        #expect(mockDelegate.stateToRender?.kind == .failed)
        #expect(mockCryptoService.passedDeviceResponse?.documents == nil)
        #expect(mockCryptoService.passedDeviceResponse?.status == .generalError)
    }

    // MARK: - userApprovedConsent
    @Test("userApprovedConsent notifies delegate with failed state when session is nil")
    func userApprovedConsentWithNoSession() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        #expect(sut.session == nil)

        // When
        sut.userDidApprove()

        // Then
        #expect(mockDelegate.stateToRender == .failed(.generic("Session is not available.")))
    }

    @Test("userApprovedConsent transitions session to processingResponse and notifies delegate")
    mutating func userApprovedConsentTransitionsToProcessingResponse() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        sut.start()
        sut.bluetoothTransportConnectionDidConnect()

        let session = try #require(sut.session as? ISOHolderSession)
        // swiftlint:disable:next line_length
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ")))
        try session.transition(to: .awaitingUserConsent(deviceRequest))

        // When
        sut.userDidApprove()

        // Then
        #expect(session.currentState == .processingResponse)
        #expect(mockDelegate.stateToRender == .processingResponse)
    }

    @Test("userApprovedConsent notifies delegate with failed state when transition throws")
    mutating func userApprovedConsentRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.missingPrerequisitesToReturn = []
        sut = ISOHolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService,
            credentialRequestHandler: mockCredentialRequestHandler
        )
        sut.delegate = mockDelegate
        sut.start()

        // Force session into a terminal state so transition to .processingResponse throws
        try sut.session?.transition(to: .cancelled)

        // When
        sut.userDidApprove()

        // Then
        #expect(mockDelegate.stateToRender?.kind == .failed)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
