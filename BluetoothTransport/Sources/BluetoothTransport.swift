import Foundation

// MARK: - Protocols
public protocol BluetoothSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
    var connectionHandle: ConnectionHandle? { get }
    func setConnection(_ connectionHandle: ConnectionHandle) throws
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

// MARK: - BluetoothTransportProtocol Implementation
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
        
        guard let blePeripheralTransport = blePeripheralTransport,
                    blePeripheralTransport.delegate != nil else {
            throw PeripheralError.addServiceError("blePeripheralTransport should not be nil")
        }
        
        let connectionHandle = ConnectionHandle(bluetoothTransport: blePeripheralTransport)
        try session.setConnection(connectionHandle)
    }
    
    func stopAdvertising() {
        blePeripheralTransport?.endSession()
    }
}

// MARK: - BluetoothTransportDelegate Implementation
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
        delegate?.bluetoothTransportDidReceiveMessageEndRequest()
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        delegate?.bluetoothTransportDidFail(with: error)
    }
}

// MARK: - ConnectionHandle
public class ConnectionHandle {
    let bluetoothTransport: BlePeripheralTransportProtocol
    
    public init(bluetoothTransport: BlePeripheralTransportProtocol) {
        self.bluetoothTransport = bluetoothTransport
    }
    
    deinit {
        bluetoothTransport.endSession()
    }
}
