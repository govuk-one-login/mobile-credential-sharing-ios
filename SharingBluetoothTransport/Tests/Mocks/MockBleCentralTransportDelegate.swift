import SharingBluetoothTransport

class MockBleCentralTransportDelegate: BleCentralTransportDelegate {
    var didDiscoverPeripheralCalled = false

    func bleCentralTransportDidDiscoverPeripheral() {
        didDiscoverPeripheralCalled = true
    }
}
