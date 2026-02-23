import BluetoothTransport
import Foundation

class MockBluetoothTransportDelegate: BluetoothTransportDelegate {
    var didCallStartAdvertising: Bool = false
    
    func bluetoothTransportDidStartAdvertising() {
        didCallStartAdvertising = true
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
}
