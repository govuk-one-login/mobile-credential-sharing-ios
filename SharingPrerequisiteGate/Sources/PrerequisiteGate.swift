import CoreBluetooth
import Foundation
import SharingBluetoothTransport
import SharingCameraService

public protocol PrerequisiteGateProtocol {
    var blePeripheralTransport: BlePeripheralTransportProtocol? { get set }
    @MainActor func triggerResolution(for missingPrerequisite: MissingPrerequisite)
    func evaluatePrerequisites(for required: [Prerequisite], completion: @escaping () -> Void) -> [MissingPrerequisite]
}

public class PrerequisiteGate: NSObject, PrerequisiteGateProtocol {
    // We must maintain a strong references to enable the CoreBluetooth OS prompt to be displayed & permissions state to be tracked
    public var blePeripheralTransport: BlePeripheralTransportProtocol?
    private let cbManagerAuthorization: () -> CBManagerAuthorization
    private let requestBluetoothPowerOn: () -> PeripheralManager
    private let cameraCapability: CameraCapabilityProviding
    private var pendingBluetoothCompletion: (() -> Void)?
    private var pendingCameraCompletion: (() -> Void)?
    
    // Public init with no parameters to expose to consumer
    public convenience override init() {
        self.init(
            cbManagerAuthorization: CBManager.authorization,
            requestBluetoothPowerOn: BluetoothPowerOnRequest<CBPeripheralManager>()
                .callAsFunction(),
            cameraHardware: CameraCapabilityProvider()
        )
    }

    // Internal init for testing purposes
    internal init(
        cbManagerAuthorization: @autoclosure @escaping () -> CBManagerAuthorization,
        requestBluetoothPowerOn: @autoclosure @escaping () -> PeripheralManager,
        cameraHardware: CameraCapabilityProviding = CameraCapabilityProvider()
    ) {
        self.cbManagerAuthorization = cbManagerAuthorization
        self.requestBluetoothPowerOn = requestBluetoothPowerOn
        self.cameraCapability = cameraHardware
    }
 
    @MainActor
    public func triggerResolution(for missingPrerequisite: MissingPrerequisite) {
        switch missingPrerequisite {
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
        case .camera(let reason):
            switch reason {
            case .authorizationNotDetermined:
                guard let completion = pendingCameraCompletion else { return}
                pendingCameraCompletion = nil
                    
                cameraCapability.requestAccess { _ in
                    Task { @MainActor in
                        completion()
                    }
                }
            default:
                break
            }
        }
    }
    
    /// Stores `pendingBluetoothCompletion` so it can be invoked later by the
    /// `BluetoothTransportDelegate` when Core Bluetooth reports its actual state.
    /// On the first evaluation, `CBPeripheralManager` may not have fully initialised yet,
    /// causing the Bluetooth state to be reported as `.unknown`. When that happens the
    /// orchestrator returns early and waits. Once Core Bluetooth finishes spinning up it
    /// fires `bluetoothTransportDidPowerOn()` (or `didFail`), which calls the stored
    /// completion to re-run preflight checks with the resolved state.
    public func evaluatePrerequisites(for required: [Prerequisite] = Prerequisite.allCases, completion: @escaping () -> Void) -> [MissingPrerequisite] {
        required.compactMap { prerequisite in
            let auth = self.cbManagerAuthorization()
            switch prerequisite {
            case .bluetooth:
                self.pendingBluetoothCompletion = completion
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
                self.pendingCameraCompletion = completion
                return checkCameraState()
            }
        }
    }
    
    private func checkCameraState() -> MissingPrerequisite? {
        guard cameraCapability.isCameraAvailable else {
            return .camera(.stateUnsupported)
        }
        switch cameraCapability.authorizationStatus {
        case .authorized:
            print("Camera access granted")
            return nil
        case .notDetermined:
            print("Camera requires access")
            return MissingPrerequisite.camera(.authorizationNotDetermined)
        case .denied:
            return MissingPrerequisite.camera(.authorizationDenied)
        case .restricted:
            return MissingPrerequisite.camera(.authorizationRestricted)
        @unknown default:
            return nil
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
            print("Bluetooth access granted")
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
            print("Triggering Preflight checks again")
            completion()
        }
    }
    
    public func bluetoothTransportDidFail(with error: PeripheralError) {
        if let completion = pendingBluetoothCompletion {
            self.pendingBluetoothCompletion = nil
            print("Triggering Preflight checks again")
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
    
    public func bluetoothTransportDidFinishSending() {
        // These protocol functions are not used as PrerequisiteGate is used as a temporary delegate
    }
}
