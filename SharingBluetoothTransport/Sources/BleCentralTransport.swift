import CoreBluetooth
import Foundation

public protocol BleCentralTransportDelegate: AnyObject {
    func bleCentralTransportDidPowerOn()
    func bleCentralTransportDidDiscoverPeripheral()
    func bleCentralTransportDidFail(with error: CentralError)
}

public protocol BleCentralTransportProtocol: AnyObject {
    var delegate: BleCentralTransportDelegate? { get set }
    func startScanning(in session: BluetoothSessionProtocol) throws
    func handleDidBeginScan()
    func stopScanning()
}

public final class BleCentralTransport: NSObject, BleCentralTransportProtocol {
    public weak var delegate: BleCentralTransportDelegate?

    private(set) var serviceCBUUID: CBUUID?
    private var centralManager: CentralManagerProtocol

    init(centralManager: CentralManagerProtocol) {
        self.centralManager = centralManager
        super.init()
        self.centralManager.delegate = self
    }

    public convenience override init() {
        self.init(
            centralManager: CBCentralManager(
                delegate: nil,
                queue: nil
            )
        )
    }

    deinit {
        stopScanning()
    }
}

public extension BleCentralTransport {
    func startScanning(in session: BluetoothSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw CentralError.serviceUUIDNotSet
        }
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        handleDidBeginScan()
    }

    func handleDidBeginScan() {
        guard let serviceCBUUID,
              centralManager.state == .poweredOn,
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
}

extension BleCentralTransport {
    internal func onError(_ error: CentralError) {
        delegate?.bleCentralTransportDidFail(with: error)
        print(error.errorDescription ?? "")
    }

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

    func handleDidDiscoverPeripheral() {
        print("Discovered peripheral advertising service UUID: \(serviceCBUUID?.uuidString ?? "")")
        delegate?.bleCentralTransportDidDiscoverPeripheral()
    }
}
