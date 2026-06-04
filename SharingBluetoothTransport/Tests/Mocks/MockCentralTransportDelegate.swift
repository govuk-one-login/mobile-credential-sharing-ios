import SharingBluetoothTransport

class MockCentralTransportDelegate: CentralTransportDelegate {
    var didPowerOnCalled = false
    var didDiscoverPeripheralCalled = false
    var didFailError: CentralError?

    func centralTransportDidPowerOn() {
        didPowerOnCalled = true
    }

    func centralTransportDidDiscoverPeripheral() {
        didDiscoverPeripheralCalled = true
    }

    func centralTransportDidFail(with error: CentralError) {
        didFailError = error
    }
}
