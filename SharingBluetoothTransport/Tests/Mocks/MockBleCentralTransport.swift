import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var startScanningCalled = false
    var stopScanningCalled = false
    var connectCalled = false
    var discoverServicesCalled = false
    var discoverCharacteristicsCalled = false

    func startScanning() {
        startScanningCalled = true
    }

    func stopScanning() {
        stopScanningCalled = true
    }

    func connect() {
        connectCalled = true
    }

    func discoverServices() {
        discoverServicesCalled = true
    }

    func discoverCharacteristics() {
        discoverCharacteristicsCalled = true
    }
}
