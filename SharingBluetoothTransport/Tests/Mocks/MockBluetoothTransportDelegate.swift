import BluetoothTransport
import Foundation

class MockBluetoothTransportDelegate: BluetoothTransportDelegate {
    var didCallStartAdvertising: Bool = false
    var didCallConnectionDidConnect: Bool = false
    var didCallDidReceiveMessageData: Bool = false
    var receivedMessageData: Data?
    var didCallDidFail: Bool = false
    var didReceiveMessageEndRequest: Bool = false
    
    func bluetoothTransportDidPowerOn() {
        
    }
    
    func bluetoothTransportDidFail(with error: PeripheralError) {
        didCallDidFail = true
    }
    
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
        didReceiveMessageEndRequest = true
    }
}
