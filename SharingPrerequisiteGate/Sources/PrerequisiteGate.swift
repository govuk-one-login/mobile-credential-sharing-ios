import CoreBluetooth
import Foundation
import SharingBluetoothTransport

public protocol PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get set }
    var delegate: PrerequisiteGateDelegate? { get set }
    func requestPermission(for missingCapability: MissingCapability)
    func checkCapabilities(for capabilities: [Capability]) -> [MissingCapability]
}

public protocol PrerequisiteGateDelegate: AnyObject {
    func prerequisiteGateBluetoothDidReportChange()
}

public class PrerequisiteGate: NSObject, PrerequisiteGateProtocol {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    public var blePeripheralTransport: BlePeripheralTransportProtocol?
    public weak var delegate: PrerequisiteGateDelegate?
    private let cbManagerAuthorization: () -> CBManagerAuthorization
    private let requestBluetoothPowerOn: () -> PeripheralManager
    
    // Public init with no parameters to expose to consumer
    public convenience override init() {
        self.init(
            cbManagerAuthorization: CBManager.authorization,
            requestBluetoothPowerOn: BluetoothPowerOnRequest<CBPeripheralManager>()
                .callAsFunction()
        )
    }

    // Internal init for testing purposes
    internal init(
        cbManagerAuthorization: @autoclosure @escaping () -> CBManagerAuthorization,
        requestBluetoothPowerOn: @autoclosure @escaping () -> PeripheralManager
    ) {
        self.cbManagerAuthorization = cbManagerAuthorization
        self.requestBluetoothPowerOn = requestBluetoothPowerOn
    }
 
    public func requestPermission(for missingCapability: MissingCapability) {
        guard let reason = missingCapability.reason as? MissingBluetoothCapabilityReason else { return }
        switch reason {
        case .bluetoothAuthNotDetermined:
            blePeripheralTransport = BlePeripheralTransport(serviceUUID: UUID())
            blePeripheralTransport?.delegate = self
        case .bluetoothStatePoweredOff:
            _ = requestBluetoothPowerOn()
        default:
            break
        }
    }
    
    public func checkCapabilities(for capabilities: [Capability] = Capability.allCases) -> [MissingCapability] {
        capabilities.compactMap { capability in
            let auth = self.cbManagerAuthorization()
            switch capability {
            case .bluetooth:
                switch auth {
                case .allowedAlways:
                    return checkAndHandleBluetoothState()
                case .notDetermined:
                    return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthNotDetermined)
                case .denied:
                    return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthDenied)
                case .restricted:
                    return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthRestricted)
                default:
                    return nil
                }
            case .camera:
                return nil
            }
        }
    }
    
    private func checkAndHandleBluetoothState() -> MissingCapability? {
        if blePeripheralTransport == nil {
            blePeripheralTransport = BlePeripheralTransport(
                serviceUUID: UUID()
            )
            blePeripheralTransport?.delegate = self
        }
        switch blePeripheralTransport?.peripheralManagerState() {
        case .poweredOn:
            return nil
        case .poweredOff:
            return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStatePoweredOff)
        case .resetting:
            return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateResetting)
        case .unsupported:
            return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateUnsupported)
        case .unknown:
            return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothStateUnknown)
        case .unauthorized:
            return MissingCapability(type: .bluetooth, reason: MissingBluetoothCapabilityReason.bluetoothAuthDenied)
        default:
            return nil
        }
    }
}

extension PrerequisiteGate: BluetoothTransportDelegate {
    public func bluetoothTransportDidPowerOn() {
        delegate?.prerequisiteGateBluetoothDidReportChange()
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        delegate?.prerequisiteGateBluetoothDidReportChange()
    }
    
    public func bluetoothTransportDidStartAdvertising() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func bluetoothTransportConnectionDidConnect() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func bluetoothTransportDidReceiveMessageData(_ messageData: Data) {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
    
    public func bluetoothTransportDidReceiveMessageEndRequest() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
}
