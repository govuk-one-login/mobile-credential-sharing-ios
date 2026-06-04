import SharingBluetoothTransport

class MockCentralTransport: CentralTransportProtocol {
    weak var delegate: CentralTransportDelegate?

    var startScanningCalled = false
    var startScanningSession: CentralSessionProtocol?
    var stopScanningCalled = false
    var startScanningShouldThrow: Error?

    func startScanning(in session: CentralSessionProtocol) throws {
        if let error = startScanningShouldThrow {
            throw error
        }
        startScanningCalled = true
        startScanningSession = session
    }

    func stopScanning() {
        stopScanningCalled = true
    }
}
