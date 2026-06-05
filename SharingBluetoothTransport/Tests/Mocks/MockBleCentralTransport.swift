import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var startScanningCalled = false
    var handleDidBeginScanCalled = false
    var stopScanningCalled = false
    var startScanningShouldThrow: Error?

    func startScanning(in session: BluetoothSessionProtocol) throws {
        if let error = startScanningShouldThrow { throw error }
        startScanningCalled = true
    }

    func handleDidBeginScan() {
        handleDidBeginScanCalled = true
    }

    func stopScanning() {
        stopScanningCalled = true
    }
}
