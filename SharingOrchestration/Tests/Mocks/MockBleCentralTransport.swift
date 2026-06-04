import CoreBluetooth
import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?

    var startScanningCalled = false
    var startScanningSession: CentralSessionProtocol?
    var handleDidStopScanningCalled = false
    var startScanningShouldThrow: Error?

    func startScanning(in session: CentralSessionProtocol) throws {
        if let error = startScanningShouldThrow {
            throw error
        }
        startScanningCalled = true
        startScanningSession = session
    }

    func handleDidStopScanning() {
        handleDidStopScanningCalled = true
    }
}
