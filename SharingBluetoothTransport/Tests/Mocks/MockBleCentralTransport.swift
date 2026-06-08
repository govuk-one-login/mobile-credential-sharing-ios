import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var startScanningCalled = false
    var stopScanningCalled = false

    func startScanning() {
        startScanningCalled = true
    }

    func stopScanning() {
        stopScanningCalled = true
    }
}
