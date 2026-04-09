import CoreBluetooth
import Foundation
import SharingBluetoothTransport

public protocol PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get set }
    func triggerResolution(for missingPrerequisite: MissingPrerequisite, completion: @escaping () -> Void)
    func evaluatePrerequisites(for required: [Prerequisite]) -> [MissingPrerequisite]
}

public class PrerequisiteGate: NSObject, PrerequisiteGateProtocol {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    public var blePeripheralTransport: BlePeripheralTransportProtocol?
    private let cbManagerAuthorization: () -> CBManagerAuthorization
    private let requestBluetoothPowerOn: () -> PeripheralManager
    private var pendingBluetoothCompletion: (() -> Void)?
    
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
 
    public func triggerResolution(for missingPrerequisite: MissingPrerequisite, completion: @escaping () -> Void) {
        switch missingPrerequisite {
        case .bluetooth(let reason):
            self.pendingBluetoothCompletion = completion
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
    
    public func evaluatePrerequisites(for required: [Prerequisite] = Prerequisite.allCases) -> [MissingPrerequisite] {
        required.compactMap { prerequisite in
            let auth = self.cbManagerAuthorization()
            switch prerequisite {
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
        if let completion = pendingBluetoothCompletion {
            self.pendingBluetoothCompletion = nil
            completion()
        }
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        if let completion = pendingBluetoothCompletion {
            self.pendingBluetoothCompletion = nil
            completion()
        }
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
