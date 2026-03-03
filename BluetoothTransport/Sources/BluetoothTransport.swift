import Foundation

public protocol BluetoothSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
}

public protocol BluetoothTransportProtocol {
    var delegate: BluetoothTransportDelegate? { get set }
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get }
    func startAdvertising(in session: BluetoothSessionProtocol) throws
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidPowerOn()
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportConnectionDidConnect()
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data)
    func bluetoothTransportDidReceiveMessageEndRequest()
    func bluetoothTransportDidFail(with error: PeripheralError)
}

public class BluetoothTransport: BluetoothTransportProtocol {
    private(set) public var blePeripheralTransport: BlePeripheralTransportProtocol?
    public weak var delegate: BluetoothTransportDelegate?
    
    // Internal init for testing
    internal init(blePeripheralTransport: BlePeripheralTransportProtocol? = nil) {
        self.blePeripheralTransport = blePeripheralTransport
    }
    
    public convenience init() {
        self.init(blePeripheralTransport: nil)
    }
    
    public func startAdvertising(in session: BluetoothSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw PeripheralError.addServiceError("serviceUUID not set")
        }
        if blePeripheralTransport == nil {
            blePeripheralTransport = BlePeripheralTransport(serviceUUID: serviceUUID)
            blePeripheralTransport?.delegate = self
        }
    }
}

extension BluetoothTransport: BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        blePeripheralTransport?.startAdvertising()
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        delegate?.bluetoothTransportConnectionDidConnect()
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        delegate?.bluetoothTransportDidReceiveMessageData(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        delegate?.bluetoothTransportDidFail(with: error)
    }
}
