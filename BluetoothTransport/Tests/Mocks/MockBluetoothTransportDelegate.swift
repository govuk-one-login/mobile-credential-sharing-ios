import BluetoothTransport
import Foundation

class MockBluetoothTransportDelegate: BluetoothTransportDelegate {
    var didCallStartAdvertising: Bool = false
    var didCallConnectionDidConnect: Bool = false
    var didCallDidReceiveMessageData: Bool = false
    var receivedMessageData: Data?
    
    func bluetoothTransportDidStartAdvertising() {
        didCallStartAdvertising = true
    }
    
    func bluetoothTransportConnectionDidConnect() {
        didCallConnectionDidConnect = true
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didCallDidReceiveMessageData = true
        receivedMessageData = messageData
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
}
