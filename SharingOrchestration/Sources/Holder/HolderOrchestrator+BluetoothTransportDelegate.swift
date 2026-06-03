import Foundation
import SharingBluetoothTransport

// MARK: - BluetoothTransport Delegate
extension HolderOrchestrator: @MainActor BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        // This delegate function is not used by the HolderOrchestrator
    }

    public func bluetoothTransportDidFail(with error: PeripheralError) {
        handleEvent(.bluetoothFailed(error))
    }

    public func bluetoothTransportDidStartAdvertising() {
        handleEvent(.advertisingStarted)
    }

    public func bluetoothTransportConnectionDidConnect() {
        handleEvent(.connectionEstablished)
    }

    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        handleEvent(.dataReceived(messageData))
    }

    public func bluetoothTransportDidReceiveMessageEndRequest() {
        handleEvent(.receivedEndRequest)
    }

    public func bluetoothTransportDidFinishSending() {
        handleEvent(.sendCompleted)
    }
}
