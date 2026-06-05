import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var startScanningCalled = false
    var handleDidStopScanningCalled = false
    var startScanningShouldThrow: Error?

    func startScanning(in session: BluetoothSessionProtocol) throws {
        if let error = startScanningShouldThrow { throw error }
        startScanningCalled = true
    }

    func handleDidStopScanning() {
        handleDidStopScanningCalled = true
    }
}
