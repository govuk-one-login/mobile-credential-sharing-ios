import CoreBluetooth
import SharingBluetoothTransport

class MockBleCentralTransportDelegate: BleCentralTransportDelegate {
    var didPowerOnCalled = false
    var didDiscoverPeripheralCalled = false
    var didConnectCalled = false
    var didDiscoverServicesCalled = false
    var didDiscoverCharacteristicsService: CBService?
    var didFailError: CentralError?
    var receivedMessageData: Data?

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

    func bleCentralTransportDidRecieveMessageData(_ messageData: Data) {
        receivedMessageData = messageData
    }

    func bleCentralTransportDidFail(with error: CentralError) {
        didFailError = error
    }
}
