import CoreBluetooth
import SharingBluetoothTransport

class MockBleCentralTransportDelegate: BleCentralTransportDelegate {
    var didPowerOnCalled = false
    var didDiscoverPeripheralCalled = false
    var didConnectCalled = false
    var didDiscoverServicesCalled = false
    var didDiscoverCharacteristicsService: CBService?
    var didFinishSendingCalled = false
    var didStartSessionCalled = false
    var didFailError: CentralError?
    var receivedMessageData: Data?
    var didReceiveMessageEndRequestCalled = false

    func bleCentralTransportDidPowerOn() {
        didPowerOnCalled = true
    }

    func bleCentralTransportDidDiscoverPeripheral() {
        didDiscoverPeripheralCalled = true
    }

    func bleCentralTransportDidConnect() {
        didConnectCalled = true
    }

    func bleCentralTransportDidDiscoverServices() {
        didDiscoverServicesCalled = true
    }

    func bleCentralTransportDidDiscoverCharacteristics(for service: CBService) {
        didDiscoverCharacteristicsService = service
    }

    func bleCentralTransportDidReceiveMessageData(_ messageData: Data) {
        receivedMessageData = messageData
    }
    
    func bleCentralTransportDidReceiveMessageEndRequest() {
        didReceiveMessageEndRequestCalled = true
    }
    
    func bleCentralTransportDidFinishSending() {
        didFinishSendingCalled = true
    }
    
    func bleCentralTransportDidStartSession() {
        didStartSessionCalled = true
    }

    func bleCentralTransportDidFail(with error: CentralError) {
        didFailError = error
    }
}
