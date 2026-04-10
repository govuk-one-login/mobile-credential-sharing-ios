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
        let mockPeripheralSession = MockBlePeripheralTransport(mockPeripheralManagerState: .poweredOn)
        let prerequisite: [Prerequisite] = [.bluetooth]
        
        let result = sut.evaluatePrerequisites(for: prerequisite) {}
        
        for auth in [CBManagerAuthorization.allowedAlways, .notDetermined, .denied, .restricted] {
            sut = PrerequisiteGate(cbManagerAuthorization: auth, requestBluetoothPowerOn: BluetoothPowerOnRequest<MockCBPeripheralManager>()
                .callAsFunction())
            sut.blePeripheralTransport = mockPeripheralSession
            
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
        _ = sut.evaluatePrerequisites() {}
        
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
    

    @Test("bluetoothTransportDidPowerOn calls delegate func")
    func bluetoothTransportDidPowerOnCallsDelegate() async throws {
        // Given
        var completionCalled = false
        let pendingBluetoothCompletion = {
            completionCalled = true
        }
        _ = sut.evaluatePrerequisites(completion: pendingBluetoothCompletion)
        
        // When
        sut.bluetoothTransportDidPowerOn()
        
        // Then
        #expect(completionCalled == true)
    }
//    
//    @Test("bluetoothTransportDidFail calls delegate func")
//    func bluetoothTransportDidFailCallsDelegate() async throws {
//        // Given
//        let mockDelegate = MockPrerequisiteGateDelegate()
//        sut.delegate = mockDelegate
//        #expect(mockDelegate.didReportChangeCalled == false)
//        
//        // When
//        sut.bluetoothTransportDidFail(with: .unknown)
//        
//        // Then
//        #expect(mockDelegate.didReportChangeCalled == true)
//    }
//    
//    @Test("bluetoothTransportDidStartAdvertising does not forward to delegate")
//    func didStartAdvertisingDoesNotCallDelegate() {
//        // Given
//        let mockDelegate = MockPrerequisiteGateDelegate()
//        sut.delegate = mockDelegate
//        #expect(mockDelegate.didReportChangeCalled == false)
//        
//        // When
//        sut.bluetoothTransportDidStartAdvertising()
//        
//        // Then
//        #expect(mockDelegate.didReportChangeCalled == false)
//    }
//    
//    @Test("bluetoothTransportConnectionDidConnect does not forward to delegate")
//    func didConnectCentralDoesNotCallDelegate() {
//        // Given
//        let mockDelegate = MockPrerequisiteGateDelegate()
//        sut.delegate = mockDelegate
//        #expect(mockDelegate.didReportChangeCalled == false)
//        
//        // When
//        sut.bluetoothTransportConnectionDidConnect()
//        
//        // Then
//        #expect(mockDelegate.didReportChangeCalled == false)
//    }
//    
//    @Test("bluetoothTransportDidReceiveMessageData does not forward to delegate")
//    func didReceiveMessageDataDoesNotCallDelegate() {
//        // Given
//        let mockDelegate = MockPrerequisiteGateDelegate()
//        sut.delegate = mockDelegate
//        #expect(mockDelegate.didReportChangeCalled == false)
//        
//        // When
//        sut.bluetoothTransportDidReceiveMessageData(Data())
//        
//        // Then
//        #expect(mockDelegate.didReportChangeCalled == false)    }
//    
//    @Test("bluetoothTransportDidReceiveMessageEndRequest does not forward to delegate")
//    func didReceiveMessageEndRequestDoesNotCallDelegate() {
//        // Given
//        let mockDelegate = MockPrerequisiteGateDelegate()
//        sut.delegate = mockDelegate
//        #expect(mockDelegate.didReportChangeCalled == false)
//        
//        // When
//        sut.bluetoothTransportDidReceiveMessageEndRequest()
//        
//        // Then
//        #expect(mockDelegate.didReportChangeCalled == false)
//    }
}
