import SharingBluetoothTransport

class MockBleCentralTransportDelegate: BleCentralTransportDelegate {
    var didPowerOnCalled = false
    var didDiscoverPeripheralCalled = false
    var didFailError: CentralError?

    func bleCentralTransportDidPowerOn() {
        didPowerOnCalled = true
    }

    func bleCentralTransportDidDiscoverPeripheral() {
        didDiscoverPeripheralCalled = true
    }

    func bleCentralTransportDidFail(with error: CentralError) {
        didFailError = error
    }
}
