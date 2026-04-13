import CoreBluetooth
import Foundation
import SharingBluetoothTransport
@testable import SharingPrerequisiteGate
import Testing

@Suite("Prerequisite Gate Tests")
struct PrerequisiteGateTests {
    var sut = PrerequisiteGate()
    
    @Test("evaluatePrerequisites returns correct MissingPrerequisite for each CBManagerState")
    func evaluatePrerequisitesReturnCorrectState() throws {
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        sut.blePeripheralTransport = mockBlePeripheralTransport
        let prerequisite: [Prerequisite] = [.bluetooth]
        
        for state in [CBManagerState.poweredOn, .poweredOff, .resetting, .unknown, .unauthorized, .unsupported] {
            mockBlePeripheralTransport.mockPeripheralManagerState = state
            
            let result = sut.evaluatePrerequisites(for: prerequisite) {}
            
            switch state {
            case .poweredOn:
                #expect(result == [])
            case .unknown:
                #expect(result == [MissingPrerequisite.bluetooth(.stateUnknown)])
            case .resetting:
                #expect(result == [MissingPrerequisite.bluetooth(.stateResetting)])
            case .unsupported:
                #expect(result == [MissingPrerequisite.bluetooth(.stateUnsupported)])
            case .unauthorized:
                #expect(result == [MissingPrerequisite.bluetooth(.stateUnauthorized)])
            case .poweredOff:
                #expect(result == [MissingPrerequisite.bluetooth(.statePoweredOff)])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("evaluatePrerequisites returns correct MissingPrerequisite for each CBManagerAuthorization")
    mutating func evaluatePrerequisitesReturnCorrectAuth() throws {
        let mockBlePeripheralTransport = MockBlePeripheralTransport(mockPeripheralManagerState: .poweredOn)
        let prerequisite: [Prerequisite] = [.bluetooth]
        
        for auth in [CBManagerAuthorization.allowedAlways, .notDetermined, .denied, .restricted] {
            sut = PrerequisiteGate(cbManagerAuthorization: auth, requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>()
                .callAsFunction())
            sut.blePeripheralTransport = mockBlePeripheralTransport
            
            let result = sut.evaluatePrerequisites(for: prerequisite) {}
            
            switch auth {
            case .notDetermined:
                    #expect(result == [MissingPrerequisite.bluetooth(.authorizationNotDetermined)])
            case .restricted:
                    #expect(result == [MissingPrerequisite.bluetooth(.authorizationRestricted)])
            case .denied:
                    #expect(result == [MissingPrerequisite.bluetooth(.authorizationDenied)])
            case .allowedAlways:
                #expect(result == [])
            @unknown default:
                fatalError("Should never be reached as all cases are covered")
            }
        }
    }
    
    @Test("Ensures CBPeripheralManager is initialized when triggerResolution(for: MissingPrerequisite.bluetooth(.statePoweredOff))")
    mutating func showPowerAlertKeyIsTrue() throws {
        // Given
        MockCBPeripheralManager.initCalled = false
        #expect(MockCBPeripheralManager.initCalled == false)
        sut = PrerequisiteGate(
            cbManagerAuthorization: .allowedAlways,
            requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>().callAsFunction()
        )
        let mockBlePeripheralTransport = MockBlePeripheralTransport()
        sut.blePeripheralTransport = mockBlePeripheralTransport
        
        // When
        sut.triggerResolution(for: MissingPrerequisite.bluetooth(.statePoweredOff))
        
        // Then
        #expect(MockCBPeripheralManager.initCalled == true)
        #expect(MockCBPeripheralManager.options as? [String: Bool] == [CBPeripheralManagerOptionShowPowerAlertKey: true])
    }
    
    @Test("evaluatePrerequisites initialises a BlePeripheralTransport if one does not exist")
    func initsPeripheralSession() {
        // Given
        #expect(sut.blePeripheralTransport == nil)

        // When
        _ = sut.evaluatePrerequisites(completion: {})
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
    }
    
    @Test("triggerResolution(for: MissingPrerequisite.bluetooth(.authorizationNotDetermined)) initiates a BlePeripheralTransport")
    func triggerResolutionInitiatesCorrectly() {
        // Given
        #expect(sut.blePeripheralTransport == nil)
        
        // When
        sut.triggerResolution(for: MissingPrerequisite.bluetooth(.authorizationNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport != nil)
    }
    
    @Test("triggerResolution(for: MissingPrerequisite.bluetooth(.authorizationNotDetermined)) assigns self as BlePeripheralTransport delegate")
    func triggerResolutionAssignsDelegate() {
        // Given
        #expect(sut.blePeripheralTransport?.delegate == nil)
        
        // When
        sut.triggerResolution(for: MissingPrerequisite.bluetooth(.authorizationNotDetermined))
        
        // Then
        #expect(sut.blePeripheralTransport?.delegate === sut.self)
    }
    

    @Test("bluetoothTransportDidPowerOn calls completion")
    func bluetoothTransportDidPowerOnCallsCompletion() async throws {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidPowerOn()
        
        // Then
        #expect(completionCalled == true)
    }
    
    @Test("bluetoothTransportDidFail calls completion")
    func bluetoothTransportDidFailCallsCompletion() async throws {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidFail(with: .unknown)
        
        // Then
        #expect(completionCalled == true)
    }
    
    @Test("bluetoothTransportDidStartAdvertising does not call completion")
    func didStartAdvertisingDoesNotCallCompletion() {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidStartAdvertising()
        
        // Then
        #expect(completionCalled == false)
    }
    
    @Test("bluetoothTransportConnectionDidConnect does not call completion")
    func didConnectCentralDoesNotCallCompletion() {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportConnectionDidConnect()
        
        // Then
        #expect(completionCalled == false)
    }
    
    @Test("bluetoothTransportDidReceiveMessageData does not call completion")
    func didReceiveMessageDataDoesNotCallCompletion() {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidReceiveMessageData(Data())
        
        // Then
        #expect(completionCalled == false)
    }
    
    @Test("bluetoothTransportDidReceiveMessageEndRequest does not call completion")
    func didReceiveMessageEndRequestDoesNotCallCompletion() {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        
        #expect(completionCalled == false)
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidReceiveMessageEndRequest()
        
        // Then
        #expect(completionCalled == false)
    }
}
