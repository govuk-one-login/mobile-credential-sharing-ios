import Foundation
import SharingBluetoothTransport

class MockBleCentralTransport: BleCentralTransportProtocol {
    weak var delegate: BleCentralTransportDelegate?
    var isConnected: Bool = true
    var startScanningCalled = false
    var stopScanningCalled = false
    var connectCalled = false
    var discoverServicesCalled = false
    var discoverCharacteristicsCalled = false
    var startTransportCalled = false
    var sendDataCalled = false
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
    
    func startTransport() {
        startTransportCalled = true
    }
    
    func send(_ data: Data) {
        sendDataCalled = true
        sentData = data
    }
    
    func endSession() {
        endSessionCalled = true
    }
}
