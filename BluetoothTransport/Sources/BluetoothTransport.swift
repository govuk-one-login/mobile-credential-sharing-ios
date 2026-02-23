import Foundation

public protocol BluetoothSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
    func setConnection(serviceUUID: UUID)
}

public protocol BluetoothTransportProtocol {
    var delegate: BluetoothTransportDelegate? { get set }
    var peripheralSession: PeripheralSessionProtocol? { get }
    func startAdvertising(in session: BluetoothSessionProtocol) throws
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data)
    func bluetoothTransportDidReceiveMessageEndRequest()
}

public class BluetoothTransport: BluetoothTransportProtocol {
    private(set) public var peripheralSession: PeripheralSessionProtocol?
    public weak var delegate: BluetoothTransportDelegate?
    
    // Internal init for testing
    internal init(peripheralSession: PeripheralSessionProtocol? = nil) {
        self.peripheralSession = peripheralSession
    }
    
    public convenience init() {
        self.init(peripheralSession: nil)
    }
    
    public func startAdvertising(in session: BluetoothSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw PeripheralError.addServiceError("serviceUUID not set")
        }
        if peripheralSession == nil {
            peripheralSession = PeripheralSession(serviceUUID: serviceUUID)
            peripheralSession?.delegate = self
        }
    }
}

extension BluetoothTransport: PeripheralSessionDelegate {
    public func peripheralSessionDidUpdateState(withError error: PeripheralError?) {
        peripheralSession?.startAdvertising()
    }
    
    public func peripheralSessionDidStartAdvertising() {
        delegate?.bluetoothTransportDidStartAdvertising()
    }
    
    public func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
    
    public func peripheralSessionDidReceiveMessageEndRequest() {
        // TODO: DCMAW-18497 To be implemented in further ticket
    }
}
