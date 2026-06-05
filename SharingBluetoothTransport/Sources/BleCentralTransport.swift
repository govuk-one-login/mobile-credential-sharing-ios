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
    func handleDidStopScanning()
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
        handleDidStopScanning()
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

    func handleDidStopScanning() {
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
                handleDidBeginScan()
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

    func handleDidDiscoverPeripheral() {
        print("Discovered peripheral advertising service UUID: \(serviceCBUUID?.uuidString ?? "")")
        handleDidStopScanning()
        delegate?.bleCentralTransportDidDiscoverPeripheral()
    }
}
