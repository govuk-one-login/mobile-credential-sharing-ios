import CoreBluetooth
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
    var isConnected: Bool { get }
    func startAdvertising(in session: BluetoothSessionProtocol) throws
    func connect(in session: BluetoothSessionProtocol) throws
    func startTransport()
    func send(_ data: Data)
    func sendSessionData(_ data: Data)
    func sendGattEnd()
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidPowerOn()
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportConnectionDidConnect()
    func bluetoothTransportDidDiscover()
    func bluetoothTransportDidStartSession()
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
    
    public var isConnected: Bool {
        bleCentralTransport?.isConnected ?? false
    }
    
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
}

// MARK: - BluetoothTransportProtocol Peripheral public consumer functions
extension BluetoothTransport {
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
    
    public func sendSessionData(_ data: Data) {
        blePeripheralTransport?.send(data)
    }
    
    public func sendGattEnd() {
        blePeripheralTransport?.endSession(andNotify: true)
    }
}

// MARK: - BluetoothTransportProtocol Central public consumer functions
extension BluetoothTransport {
    public func connect(in session: BluetoothSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw CentralError.serviceUUIDNotSet
        }
        if bleCentralTransport == nil {
            bleCentralTransport = BleCentralTransport(serviceUUID: serviceUUID)
            bleCentralTransport?.delegate = self
        }
        
        let connectionHandle = ConnectionHandle(bleCentralTransport: bleCentralTransport)
        try session.setConnection(connectionHandle)
    }
    
    public func startTransport() {
        bleCentralTransport?.startTransport()
    }
    
    public func send(_ data: Data) {
        bleCentralTransport?.send(data)
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
    
    public func bluetoothTransportDidDiscover() {
        delegate?.bluetoothTransportDidDiscover()
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
    
    public func bluetoothTransportDidFinishSending() {
        delegate?.bluetoothTransportDidFinishSending()
    }
    
    public func bluetoothTransportDidStartSession() {
        delegate?.bluetoothTransportDidStartSession()
    }
    
    public func bluetoothTransportDidFail(with error: BluetoothTransportError) {
        delegate?.bluetoothTransportDidFail(with: error)
    }
}

// MARK: - BleCentralTransportDelegate Implementation (Central)
extension BluetoothTransport: BleCentralTransportDelegate {
    public func bleCentralTransportDidPowerOn() {
        bleCentralTransport?.startScanning()
        delegate?.bluetoothTransportDidPowerOn()
    }

    public func bleCentralTransportDidDiscoverPeripheral() {
        bleCentralTransport?.stopScanning()
        bleCentralTransport?.connect()
        delegate?.bluetoothTransportDidDiscover()
    }

    public func bleCentralTransportDidFail(with error: CentralError) {
        delegate?.bluetoothTransportDidFail(with: .central(error))
    }
    
    public func bleCentralTransportDidConnect() {
        bleCentralTransport?.discoverServices()
    }
    
    public func bleCentralTransportDidDiscoverServices() {
        bleCentralTransport?.discoverCharacteristics()
    }
    
    public func bleCentralTransportDidDiscoverCharacteristics(for service: CBService) {
        guard let characteristics = service.characteristics else { return }
        
        for expectedType in CharacteristicType.allCases {
            guard let characteristic = characteristics.first(where: { $0.uuid == expectedType.cbUUID }),
                  characteristic.properties.contains(expectedType.properties) else {
                delegate?.bluetoothTransportDidFail(with: .central(.discoverCharacteristicsError("Incompatible mDL service: missing characteristics")))
                return
            }
        }
        
        print("Discovered characteristics: \(characteristics)")
    
        delegate?.bluetoothTransportConnectionDidConnect()
    }
    
    public func bleCentralTransportDidReceiveMessageData(_ messageData: Data) {
        delegate?.bluetoothTransportDidReceiveMessageData(messageData)
    }
    
    public func bleCentralTransportDidStartSession() {
        delegate?.bluetoothTransportDidStartSession()
    }
    
    public func bleCentralTransportDidFinishSending() {
        delegate?.bluetoothTransportDidFinishSending()
    }
}

// MARK: - ConnectionHandle
public class ConnectionHandle {
    let blePeripheralTransport: BlePeripheralTransportProtocol?
    var bleCentralTransport: BleCentralTransportProtocol?
    public var notify: Bool = false
    
    public init(
        blePeripheralTransport: BlePeripheralTransportProtocol? = nil,
        bleCentralTransport: BleCentralTransportProtocol? = nil
    ) {
        self.blePeripheralTransport = blePeripheralTransport
        self.bleCentralTransport = bleCentralTransport
    }
    
    deinit {
        blePeripheralTransport?.endSession(andNotify: notify)
        bleCentralTransport?.stopScanning()
        bleCentralTransport?.endSession()
    }
}
