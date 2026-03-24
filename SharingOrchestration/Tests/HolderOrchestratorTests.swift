import SharingBluetoothTransport
import SharingCryptoService
@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing
import UIKit

// swiftlint:disable type_body_length
// swiftlint:disable file_length
@Suite("HolderOrchestrator Tests")
struct HolderOrchestratorTests {
    var mockPrerequisiteGate = MockPrerequisiteGate()
    var mockBluetoothTransport = MockBluetoothTransport()
    var mockCryptoService = MockCryptoService()
    var sut: HolderOrchestrator
    
    init() {
        sut = HolderOrchestrator(prerequisiteGate: mockPrerequisiteGate)
    }
    
    @Test("startPresentation creates a new HolderSession object")
    func startPresentationCreatesHolderSession() {
        // Given
        #expect(sut.session == nil)
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session != nil)
    }
    
    @Test("cancelPresentation sets the session & all packages to nil")
    mutating func cancelPresentationSetsSessionToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.startPresentation()

        #expect(sut.session != nil)
        #expect(sut.prerequisiteGate != nil)
        #expect(sut.cryptoService != nil)
        #expect(sut.bluetoothTransport != nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == false)
        
        // When
        sut.cancelPresentation()
        
        // Then
        #expect(sut.session == nil)
        #expect(sut.prerequisiteGate == nil)
        #expect(sut.cryptoService == nil)
        #expect(sut.bluetoothTransport == nil)
        #expect(mockBlePeripheralTransport.endSessionCalled == true)
    }
    
    @Test("bluetoothTransportDidUpdateState triggers performPreflightChecks()")
    mutating func bluetoothTransportDidUpdateStatePreflightChecks() {
        // Given
        sut = HolderOrchestrator()
        #expect(sut.prerequisiteGate == nil)
        
        // When
        sut.prerequisiteGateBluetoothDidReportChange()
        
        // Then
        /// performPreflightChecks inits prerequisiteGate
        #expect(sut.prerequisiteGate != nil)
    }
    
    @Test("startPresentation successfully transitions to .readyToPresent when capabilities are allowed")
    func startPresentationProceedsToReadyToPresent() {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = []
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session?.currentState == .readyToPresent)
    }
    
    @Test("startPresentation successfully transitions to .preflight when capabilities are not allowed")
    func startPresentationProceedsToPreflight() {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined)]
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(sut.session?.currentState == .preflight(missingPermissions: mockPrerequisiteGate.notAllowedCapabilities))
    }
    
    @Test("requestPermissions triggers requestPermission func on PrerequisiteGate")
    func requestPermissionsTriggersPRGateFunc() throws {
        // Given
        _ = try #require(sut.prerequisiteGate)
        #expect(mockPrerequisiteGate.didCallRequestPermission == false)
        
        // When
        sut.requestPermission(for: MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined))
        
        // Then
        #expect(mockPrerequisiteGate.didCallRequestPermission == true)
    }
    
    @Test("prepareEngagement transitions to .presentingEngagement state")
    mutating func didStartAdvertisingTransitionsToPresentingEngagement() throws {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport
        )
        
        // When
        /// With bluetoothTransport mocked, startPresentation will successfully proceed to prepareEngagement
        sut.startPresentation()
        
        // Then
        let qrCode = try #require(sut.session?.qrCode)
        #expect(sut.session?.currentState == .presentingEngagement(qrCode: qrCode))
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
        #expect(mockDelegate.stateToRender == .error("Session is not available."))
    }
    
    @Test("prepareEngagement renders error when cryptoContext is nil")
    mutating func prepareEngagementRendersErrorContextNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        mockCryptoService.forceFailureWithInvalidData = true
        
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender == .error("Session engagement failed to prepare correctly."))
    }
    
    @Test("presentQRCode renders error when qrCode on session is nil")
    mutating func presentQRCodeWhenNil() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        // When
        /// Public delegate function that calls private presentQRCode function
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.stateToRender == .error( "QR Code failed to generate."))
    }
    
    @Test("connectionDidConnect transitions to .processingEstablishment state")
    mutating func connectionDidConnectTransitionsToProcessingEstablishment() throws {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport
        )
        
        // When
        sut.startPresentation()
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(sut.session?.currentState == .processingEstablishment)
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
        #expect(mockDelegate.stateToRender == .error("Session is not available."))
    }
    
    @Test(".didReceive calls cryptoService.processSessionEstablishment")
    mutating func didReceiveCallsCryptoServiceFunction() throws {
        // Given
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        
        #expect(mockCryptoService.didCallProcessSessionEstablishment == false)
        #expect(mockCryptoService.incomingBytes == nil)
        #expect(mockCryptoService.passedSession == nil)
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startPresentation()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(sut.session?.currentState == .processingEstablishment)
        #expect(mockCryptoService.didCallProcessSessionEstablishment == true)
        #expect(mockCryptoService.incomingBytes == data)
        // Checking the session matches by comparing the cryptoContext.serviceUUID
        #expect(mockCryptoService.passedSession?.cryptoContext?.serviceUUID == sut.session?.cryptoContext?.serviceUUID)
    }
    
    @Test(".didReceive transitions to requestReceived and renders state")
    mutating func didReceiveTransitionsToRequestReceivedAndRendersState() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        // swiftlint:disable:next line_length
        let cbor = "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        let deviceRequest = try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
        mockCryptoService.stubbedDeviceRequest = deviceRequest
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.delegate = mockDelegate
        
        // When
        let data = try #require(Data(base64Encoded: "Test"))
        sut.startPresentation()
        sut.bluetoothTransportConnectionDidConnect()
        sut.bluetoothTransportDidReceiveMessageData(data)
        
        // Then
        #expect(sut.session?.currentState == .requestReceived(deviceRequest))
        #expect(mockDelegate.stateToRender == .requestReceived(deviceRequest))
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
        #expect(mockDelegate.stateToRender == .error("Session is not available."))
    }
    
    @Test("bluetoothTransportDidFail renders error")
    func bluetoothTransportDidFailRendersError() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        
        #expect(sut.session == nil)
        #expect(mockDelegate.stateToRender == nil)
        
        let error = PeripheralError.unknown
        
        // When
        sut.bluetoothTransportDidFail(with: error)
        
        // Then
        #expect(mockDelegate.stateToRender == .error(try #require(error.errorDescription)))
    }
    
    @Test("cancelPresentation sets all services to nil")
    mutating func cancelPresentationSetsServicesToNil() throws {
        // Given
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        mockBluetoothTransport.blePeripheralTransport = mockBlePeripheralTransport
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            // We must set the bluetoothTransport to mock the bluetooth delegate functions
            bluetoothTransport: mockBluetoothTransport
        )
        
        // When
        /// With bluetoothTransport mocked, startPresentation will successfully proceed to prepareEngagement
        sut.startPresentation()
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
        mockPrerequisiteGate.notAllowedCapabilities = [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthDenied)]
        sut.delegate = mockDelegate
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender == .error("Bluetooth authorization denied"))
    }
    
    @Test("performPreflightChecks renders error when bluetooth auth is restricted")
    func preflightChecksRestrictedRendersError() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = [MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthRestricted)]
        sut.delegate = mockDelegate
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender == .error("Bluetooth authorization restricted"))
    }
    
    @Test("didReceive renders error when processSessionEstablishment throws")
    mutating func didReceiveRendersErrorWhenProcessingThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.delegate = mockDelegate
        
        // When
        sut.startPresentation()
        sut.bluetoothTransportConnectionDidConnect()
        // Invalid data will cause processSessionEstablishment to throw
        sut.bluetoothTransportDidReceiveMessageData(Data([0x00]))
        
        // Then
        #expect(sut.session?.currentState == .processingEstablishment)
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
    
    @Test("cancelPresentation renders cancelled state")
    func cancelPresentationRendersState() {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startPresentation()
        
        // When
        sut.cancelPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender == .cancelled)
    }
    
    // MARK: - Catch block coverage tests
    
    @Test("performPreflightChecks renders error when session transition throws")
    func preflightChecksRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut.delegate = mockDelegate
        sut.startPresentation()
        
        // Force session into a terminal state so transition to .readyToPresent throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.performPreflightChecks()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
    
    @Test("prepareEngagement renders error when startAdvertising throws")
    mutating func prepareEngagementRendersErrorWhenStartAdvertisingThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        mockBluetoothTransport.shouldThrowOnStartAdvertising = true
        
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport,
            cryptoService: mockCryptoService
        )
        sut.delegate = mockDelegate
        
        // When
        sut.startPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
    
    @Test("presentQRCode renders error when session transition to presentingEngagement throws")
    mutating func presentQRCodeRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        mockPrerequisiteGate.notAllowedCapabilities = []
        sut = HolderOrchestrator(
            prerequisiteGate: mockPrerequisiteGate,
            bluetoothTransport: mockBluetoothTransport
        )
        sut.delegate = mockDelegate
        
        // startPresentation transitions through to .presentingEngagement
        sut.startPresentation()
        #expect(sut.session?.currentState.kind == .presentingEngagement)
        
        // When — calling didStartAdvertising again tries to transition to .presentingEngagement from .presentingEngagement which is invalid
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
    
    @Test("connectionDidConnect renders error when session transition throws")
    func connectionDidConnectRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startPresentation()
        
        // Force session into a terminal state so transition to .processingEstablishment throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
    
    @Test("cancelPresentation renders error when session transition to cancelled throws")
    func cancelPresentationRendersErrorWhenTransitionThrows() throws {
        // Given
        let mockDelegate = MockHolderOrchestratorDelegate()
        sut.delegate = mockDelegate
        sut.startPresentation()
        
        // Force session into a terminal state so transition to .cancelled throws
        try sut.session?.transition(to: .cancelled)
        
        // When
        sut.cancelPresentation()
        
        // Then
        #expect(mockDelegate.stateToRender?.kind == .error)
    }
}
// swiftlint:enable type_body_length
// swiftlint:enable file_length
