import Foundation

public protocol BluetoothSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
    func setConnection(serviceUUID: UUID) throws
}

public protocol BluetoothTransportProtocol {
    var delegate: BluetoothTransportDelegate? { get set }
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get }
    func startAdvertising(in session: BluetoothSessionProtocol) throws
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data)
    func bluetoothTransportDidReceiveMessageEndRequest()
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

extension BluetoothTransport: BlePeripheralTransportDelegate {
    public func peripheralTransportDidUpdateState(withError error: PeripheralError?) {
        blePeripheralTransport?.startAdvertising()
    }
    
    public func peripheralTransportDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    public func peripheralTransportDidReceiveMessageData(_ messageData: Data) {
        delegate?.bluetoothTransportDidReceiveMessageData(messageData)
    }
    
    public func peripheralTransportDidReceiveMessageEndRequest() {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
}
