import CoreBluetooth
import Foundation

public protocol BleCentralTransportDelegate: AnyObject {
    func bleCentralTransportDidPowerOn()
    func bleCentralTransportDidDiscoverPeripheral()
    func bleCentralTransportDidFail(with error: CentralError)
}

public protocol BleCentralTransportProtocol: AnyObject {
    var delegate: BleCentralTransportDelegate? { get set }
    func startScanning()
    func stopScanning()
    func connect()
}

public final class BleCentralTransport: NSObject, BleCentralTransportProtocol {
    public weak var delegate: BleCentralTransportDelegate?
    private(set) var serviceCBUUID: CBUUID
    private(set) var peripheral: BluetoothPeripheralProtocol?
    private var centralManager: CentralManagerProtocol

    init(
        centralManager: CentralManagerProtocol,
        serviceUUID: UUID
    ) {
        self.centralManager = centralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.centralManager.delegate = self
    }

    public convenience init(serviceUUID: UUID) {
        self.init(
            centralManager: CBCentralManager(
                delegate: nil,
                queue: nil
            ),
            serviceUUID: serviceUUID
        )
    }
    
    internal func onError(_ error: CentralError) {
        delegate?.bleCentralTransportDidFail(with: error)
        print(error.errorDescription ?? "")
    }

    deinit {
        stopScanning()
    }
}

// MARK: - Public funcs
public extension BleCentralTransport {
    func startScanning() {
        guard centralManager.state == .poweredOn,
              !centralManager.isScanning else {
            return
        }
        centralManager.scanForPeripherals(
            withServices: [serviceCBUUID],
            options: nil
        )
        print("Scanning started for service UUID: \(serviceCBUUID)")
    }

    func stopScanning() {
        guard centralManager.isScanning else { return }
        centralManager.stopScan()
        print("Scanning stopped.")
    }
    
    func connect() {
        guard let peripheral else {
            return
        }
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - CBCentralManagerDelegate handle funcs
extension BleCentralTransport {
    func handleDidUpdateState(for central: any CentralManagerProtocol) {
        let authorization = central.authorization
        switch authorization {
        case .allowedAlways:
            switch central.state {
            case .poweredOn:
                delegate?.bleCentralTransportDidPowerOn()
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                onError(.notPoweredOn(central.state))
            @unknown default:
                onError(.unknown)
            }
        case .notDetermined, .restricted, .denied:
            onError(.permissionsNotGranted(authorization))
        @unknown default:
            onError(.unknown)
        }
    }

    func handleDidDiscoverPeripheral(
        for peripheral: any BluetoothPeripheralProtocol
    ) {
        self.peripheral = peripheral
        print("Discovered peripheral advertising service UUID: \(serviceCBUUID.uuidString)")
        delegate?.bleCentralTransportDidDiscoverPeripheral()
    }
    
    func handleDidConnect(
        _ peripheral: any BluetoothPeripheralProtocol
    ) {
        print("Successfully connected to peripheral: \(peripheral.name ?? "unknown name"), \(peripheral.identifier)")
        self.peripheral?.delegate = self
        self.peripheral?.discoverServices([serviceCBUUID])
    }
}

// MARK: - CBPeripheralDelegate handle funcs
extension BleCentralTransport {
    func handleDidDiscoverServices(
        for peripheral: any BluetoothPeripheralProtocol,
        error: (any Error)?
    ) {
        if let error {
            onError(.discoverServicesError(error.localizedDescription))
            return
        } else {
            guard let service = peripheral.services?.first(where: { $0.uuid == serviceCBUUID }) else {
                return
            }
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func handleDidDiscoverCharacteristics(
        for service: CBService,
        error: (any Error)?
    ) {
        if let error {
            onError(.discoverServicesError(error.localizedDescription))
            return
        } else {
            guard let characteristics = service.characteristics else { return }
            print(characteristics)
            // Use discovered characteristics here
        }
    }
}
