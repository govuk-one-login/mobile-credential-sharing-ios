import Foundation
import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var startScanningCalled = false
    var stopScanningCalled = false
    var connectCalled = false
    var discoverServicesCalled = false
    var discoverCharacteristicsCalled = false
    var startTransportCalled = false
    var sendCalled = false
    var sentData: Data?
    var endSessionCalled = false

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
    
    func startTransport() throws {
        startTransportCalled = true
    }
    
    func send(_ data: Data) throws {
        sendCalled = true
        sentData = data
    }
    
    func endSession() {
        endSessionCalled = true
    }
}
