import CoreBluetooth
import Foundation
import SharingBluetoothTransport

public protocol PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get set }
    var delegate: PrerequisiteGateDelegate? { get set }
    func requestPermission(for missingCapability: MissingPrerequisite)
    func checkCapabilities(for capabilities: [Prerequisite]) -> [MissingPrerequisite]
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
 
    public func requestPermission(for missingCapability: MissingPrerequisite) {
//        guard let reason = missingCapability.reason as? MissingBluetoothCapabilityReason else { return }
        
        switch missingCapability {
        case .bluetooth(let reason):
            switch reason {
            case .authorizationNotDetermined:
                blePeripheralTransport = BlePeripheralTransport(
                    serviceUUID: UUID()
                )
                blePeripheralTransport?.delegate = self
            case .statePoweredOff:
                _ = requestBluetoothPowerOn()
            default:
                break
            }
        case .camera:
                break
        }
    }
    
    public func checkCapabilities(for capabilities: [Prerequisite] = Prerequisite.allCases) -> [MissingPrerequisite] {
        capabilities.compactMap { capability in
            let auth = self.cbManagerAuthorization()
            switch capability {
            case .bluetooth:
                switch auth {
                case .allowedAlways:
                    return checkAndHandleBluetoothState()
                case .notDetermined:
                        return MissingPrerequisite.bluetooth(.authorizationNotDetermined)
                case .denied:
                        return MissingPrerequisite.bluetooth(.authorizationDenied)
                case .restricted:
                        return MissingPrerequisite.bluetooth(.authorizationRestricted)
                default:
                    return nil
                }
            case .camera:
                return nil
            }
        }
    }
    
    private func checkAndHandleBluetoothState() -> MissingPrerequisite? {
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
                return MissingPrerequisite.bluetooth(.statePoweredOff)
        case .resetting:
                return MissingPrerequisite.bluetooth(.stateResetting)
        case .unsupported:
                return MissingPrerequisite.bluetooth(.stateUnsupported)
        case .unknown:
                return MissingPrerequisite.bluetooth(.stateUnknown)
        case .unauthorized:
                return MissingPrerequisite.bluetooth(.stateUnauthorized)
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
