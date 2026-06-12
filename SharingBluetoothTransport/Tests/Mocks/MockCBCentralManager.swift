import CoreBluetooth
@testable import SharingBluetoothTransport

class MockCBCentralManager: CentralManagerProtocol {
    var authorization: CBManagerAuthorization = .allowedAlways
    var state: CBManagerState
    weak var delegate: (any CBCentralManagerDelegate)?
    var isScanning: Bool = false

    var didCallScanForPeripherals: Bool = false
    var scannedServiceUUIDs: [CBUUID]?
    var didCallStopScan: Bool = false
    
    var didCallConnect = false
    var connectedPeripheral: (any BluetoothPeripheralProtocol)?
    
    var didCallCancelConnection: Bool = false

    init(state: CBManagerState = .poweredOn) {
        self.state = state
    }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        didCallScanForPeripherals = true
        scannedServiceUUIDs = serviceUUIDs
        isScanning = true
    }

    func stopScan() {
        didCallStopScan = true
        isScanning = false
    }

    func connect(_ peripheral: any BluetoothPeripheralProtocol, options: [String: Any]?) {
        didCallConnect = true
        connectedPeripheral = peripheral
    }
    
    func cancelPeripheralConnection(_ peripheral: any BluetoothPeripheralProtocol) {
        didCallCancelConnection = true
    }
}
