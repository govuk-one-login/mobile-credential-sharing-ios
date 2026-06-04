import CoreBluetooth
import Foundation

public protocol CentralSessionProtocol: AnyObject {
    var serviceUUID: UUID? { get }
}

public protocol BleCentralTransportDelegate: AnyObject {
    func bleCentralTransportDidDiscoverPeripheral()
}

public protocol BleCentralTransportProtocol: AnyObject {
    var delegate: BleCentralTransportDelegate? { get set }
    func startScanning(in session: CentralSessionProtocol) throws
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
    func startScanning(in session: CentralSessionProtocol) throws {
        guard let serviceUUID = session.serviceUUID else {
            throw CentralTransportError.serviceUUIDNotSet
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
    func handleDidUpdateState() {
        if centralManager.state == .poweredOn {
            handleDidBeginScan()
        }
    }

    func handleDidBeginScan() {
        guard let serviceCBUUID else { return }
        guard centralManager.state == .poweredOn else {
            print("Central manager not powered on, waiting for state update to scan.")
            return
        }
        guard !centralManager.isScanning else { return }
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
