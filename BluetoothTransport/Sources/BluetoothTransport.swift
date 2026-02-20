import Foundation

public protocol BluetoothSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
}

public protocol BluetoothTransportProtocol {
    var delegate: BluetoothTransportDelegate? { get set }
    func startAdvertising(in session: BluetoothSessionProtocol) throws
}

public protocol BluetoothTransportDelegate: AnyObject {
    func bluetoothTransportDidUpdateState(withError error: PeripheralError?)
    func bluetoothTransportDidStartAdvertising()
    func bluetoothTransportDidReceiveMessageData(_ messageData: Data)
    func bluetoothTransportDidReceiveMessageEndRequest()
}

public class BluetoothTransport: BluetoothTransportProtocol {
    private(set) var peripheralSession: PeripheralSession?
    public weak var delegate: BluetoothTransportDelegate?
    
    public init() {}
    
    public func startAdvertising(in session: BluetoothSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw PeripheralError.addServiceError("serviceUUID not set")
        }
        peripheralSession = PeripheralSession(serviceUUID: serviceUUID)
        peripheralSession?.delegate = self
    }
}

extension BluetoothTransport: PeripheralSessionDelegate {
    public func peripheralSessionDidUpdateState(withError error: PeripheralError?) {
        
    }
    
    public func peripheralSessionDidStartAdvertising() {
        
    }
    
    public func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        
    }
    
    public func peripheralSessionDidReceiveMessageEndRequest() {
        
    }
}
