import Foundation
import SharingBluetoothTransport

class MockBluetoothTransportDelegate: BluetoothTransportDelegate {
    var didCallDidPowerOn: Bool = false
    var didCallStartAdvertising: Bool = false
    var didCallConnectionDidConnect: Bool = false
    var didCallDidReceiveMessageData: Bool = false
    var receivedMessageData: Data?
    var didCallDidFail: Bool = false
    var didReceiveMessageEndRequest: Bool = false
    var didCallDidFinishSending: Bool = false
    var didCallDidDiscover: Bool = false
    
    func bluetoothTransportDidPowerOn() {
        didCallDidPowerOn = true
    }
    
    func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        didCallDidFail = true
    }
    
    func bluetoothTransportDidStartAdvertising() {
        didCallStartAdvertising = true
    }
    
    func bluetoothTransportConnectionDidConnect() {
        didCallConnectionDidConnect = true
    }

    func bluetoothTransportDidDiscover() {
        didCallDidDiscover = true
    }
    
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        didCallDidReceiveMessageData = true
        receivedMessageData = messageData
    }
    
    func bluetoothTransportDidReceiveMessageEndRequest() {
        didReceiveMessageEndRequest = true
    }
    
    func bluetoothTransportDidFinishSending() {
        didCallDidFinishSending = true
    }
}
