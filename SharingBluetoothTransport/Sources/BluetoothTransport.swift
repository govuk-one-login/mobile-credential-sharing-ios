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
    func startScanning(in session: BluetoothSessionProtocol) throws
    func stopScanning()
    func sendSessionData(_ data: Data)
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidPowerOn()
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportConnectionDidConnect()
    func bluetoothTransportDidDiscover()
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data)
    func bluetoothTransportDidReceiveMessageEndRequest()
    func bluetoothTransportDidFinishSending()
    func bluetoothTransportDidFail(with error: BluetoothTransportError)
}

// MARK: - Error

public enum BluetoothTransportError: Equatable, LocalizedError {
    case peripheral(PeripheralError)
    case central(CentralError)

    public var errorDescription: String? {
        switch self {
        case .peripheral(let error): return error.errorDescription
        case .central(let error): return error.errorDescription
        }
    }
}

// MARK: - BluetoothTransportProtocol Implementation
public class BluetoothTransport: BluetoothTransportProtocol {
    private(set) public var blePeripheralTransport: BlePeripheralTransportProtocol?
    private(set) public var bleCentralTransport: BleCentralTransportProtocol?
    public weak var delegate: BluetoothTransportDelegate?
    
    // Internal init for testing
    internal init(
        blePeripheralTransport: BlePeripheralTransportProtocol? = nil,
        bleCentralTransport: BleCentralTransportProtocol? = nil
    ) {
        self.blePeripheralTransport = blePeripheralTransport
        self.bleCentralTransport = bleCentralTransport
    }
    
    public convenience init() {
        self.init(blePeripheralTransport: nil, bleCentralTransport: nil)
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
        
        let connectionHandle = ConnectionHandle(blePeripheralTransport: blePeripheralTransport)
        try session.setConnection(connectionHandle)
    }

    public func startScanning(in session: BluetoothSessionProtocol) throws {
        if bleCentralTransport == nil {
            bleCentralTransport = BleCentralTransport()
            bleCentralTransport?.delegate = self
        }
        try bleCentralTransport?.startScanning(in: session)
    }

    public func stopScanning() {
        bleCentralTransport?.stopScanning()
    }

    public func sendSessionData(_ data: Data) {
        blePeripheralTransport?.sendData(data)
    }
}

// MARK: - BluetoothTransportDelegate Implementation (Peripheral)
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

    public func bluetoothTransportDidDiscover() {
        delegate?.bluetoothTransportDidDiscover()
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        delegate?.bluetoothTransportDidReceiveMessageData(messageData)
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        delegate?.bluetoothTransportDidReceiveMessageEndRequest()
    }
    
    public func bluetoothTransportDidFinishSending() {
        delegate?.bluetoothTransportDidFinishSending()
    }
    
    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        delegate?.bluetoothTransportDidFail(with: error)
    }
}

// MARK: - BleCentralTransportDelegate Implementation (Central)
extension BluetoothTransport: BleCentralTransportDelegate {
    public func bleCentralTransportDidPowerOn() {
        bleCentralTransport?.handleDidBeginScan()
        delegate?.bluetoothTransportDidPowerOn()
    }

    public func bleCentralTransportDidDiscoverPeripheral() {
        bleCentralTransport?.stopScanning()
        delegate?.bluetoothTransportDidDiscover()
    }

    public func bleCentralTransportDidFail(with error: CentralError) {
        delegate?.bluetoothTransportDidFail(with: .central(error))
    }
}

// MARK: - ConnectionHandle
public class ConnectionHandle {
    let blePeripheralTransport: BlePeripheralTransportProtocol
    public var notify: Bool = false
    
    public init(blePeripheralTransport: BlePeripheralTransportProtocol) {
        self.blePeripheralTransport = blePeripheralTransport
    }
    
    deinit {
        blePeripheralTransport.endSession(andNotify: notify)
    }
}
