import BluetoothTransport
import CryptoService
@testable import Orchestration
import PrerequisiteGate
import Testing
import UIKit

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
    
    @Test("cancelPresentation sets the session to nil")
    func cancelPresentationSetsSessionToNil() {
        // Given
        sut.startPresentation()
        #expect(sut.session != nil)
        
        // When
        sut.cancelPresentation()
        
        // Then
        #expect(sut.session == nil)
    }
    
    @Test("bluetoothTransportDidUpdateState triggers performPreflightChecks()")
    mutating func bluetoothTransportDidUpdateStatePreflightChecks() {
        // Given
        sut = HolderOrchestrator()
        #expect(sut.prerequisiteGate == nil)
        
        // When
        sut.prerequisiteGateBluetoothDidUpdateState()
        
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
        mockPrerequisiteGate.notAllowedCapabilities = [.bluetooth()]
        
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
        sut.requestPermission(for: .bluetooth())
        
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
    func prepareEngagementThrowsErrorSessionNil() throws {
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
    mutating func prepareEngagementThrowsErrorContextNil() throws {
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
}
