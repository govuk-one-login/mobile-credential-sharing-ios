import CoreBluetooth
import Foundation

/// A protocol defining the core responsibilities of a Bluetooth Central Manager.
/// This abstraction facilitates dependency injection and unit testing for CoreBluetooth components.
public protocol CentralManagerProtocol: AnyObject {
    
    /// Returns the current authorization state of the central manager.
    var authorization: CBManagerAuthorization { get }

    /// The current state of the central manager (e.g., .poweredOn, .unauthorized).
    var state: CBManagerState { get }

    /// The delegate object that receives central manager events.
    var delegate: (any CBCentralManagerDelegate)? { get set }

    /// A Boolean value that indicates whether the central is currently scanning for peripherals.
    var isScanning: Bool { get }

    /// Scans for peripherals that are advertising the specified services.
    /// - Parameters:
    ///   - serviceUUIDs: An array of service UUIDs to scan for. Pass `nil` to scan for all peripherals.
    ///   - options: A dictionary of options for customising the scan.
    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)

    /// Stops scanning for peripherals.
    func stopScan()
    
    /// Initiates a connection to CBPeripheral
    /// - Parameters:
    ///   - peripheral: The `CBPeripheral` to be connected.
    ///   - options:  An optional dictionary specifying connection behavior options.
    func connect(_ peripheral: any BluetoothPeripheralProtocol, options: [String: Any]?)
}

extension CBCentralManager: CentralManagerProtocol {
    /// Connects to peripheral by bridging protocol-based peripheral back to a concrete `CBPeripheral`.
    public func connect(
        _ peripheral: any BluetoothPeripheralProtocol,
        options: [String : Any]?
    ) {
        guard let nativePeripheral: CBPeripheral = peripheral as? CBPeripheral else {
            preconditionFailure("Expected CBPeripheral but received \(type(of: peripheral))")
        }
        
        return self.connect(nativePeripheral, options: options)
    }
}
