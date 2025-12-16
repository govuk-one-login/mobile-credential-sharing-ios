import CoreBluetooth
import Foundation

public protocol PeripheralSessionDelegate: AnyObject {
    func peripheralSessionDidUpdateState(withError error: PeripheralError?)
}

public final class PeripheralSession: NSObject {
    public weak var delegate: PeripheralSessionDelegate?

    private(set) var subscribedCentrals: [CBCharacteristic: [BluetoothCentralProtocol]] = [:]
    private(set) var characteristicData: [CBCharacteristic: [Data]] = [:]
    private(set) var serviceCBUUID: CBUUID

    private var peripheralManager: PeripheralManagerProtocol

    init(
        peripheralManager: PeripheralManagerProtocol,
        serviceUUID: UUID,
    ) {
        self.peripheralManager = peripheralManager
        self.serviceCBUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
        self.peripheralManager.delegate = self
    }

    public convenience init(serviceUUID: UUID) {
        self.init(
            peripheralManager: CBPeripheralManager(
                delegate: nil,
                queue: nil,
                options: [
                    CBPeripheralManagerOptionShowPowerAlertKey: true
                ]
            ),
            serviceUUID: serviceUUID
        )
    }

    deinit {
        self.stopAdvertising()
    }
}

extension PeripheralSession {
    func startAdvertising(_ peripheral: any PeripheralManagerProtocol) {
        let service = self.mutableServiceWithServiceCharacterics(
            self.serviceCBUUID
        )
        peripheral.removeAllServices()
        peripheral.add(service)
        peripheral.startAdvertising(
            [CBAdvertisementDataServiceUUIDsKey: [service.uuid]]
        )
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
    }

    func onError(_ error: PeripheralError) {
        delegate?.peripheralSessionDidUpdateState(withError: error)
        print(error.errorDescription ?? "")
    }

    func mutableServiceWithServiceCharacterics(_ cbUUID: CBUUID) -> CBMutableService {
        let characteristics: [CBMutableCharacteristic] = CharacteristicType
            .allCases.compactMap(
                { CBMutableCharacteristic(characteristic: $0) }
            )

        let service = CBMutableService(type: cbUUID, primary: true)

        service.characteristics = characteristics
        service.includedServices = []

        return service
    }
}

extension PeripheralSession {
    func handleDidUpdateState(for peripheral: any PeripheralManagerProtocol) {
        let authorization = peripheral.authorization
        switch authorization {
        case .allowedAlways:
            switch peripheral.state {
            case .poweredOn:
                startAdvertising(peripheral)
            case .unknown, .resetting, .unsupported, .unauthorized, .poweredOff:
                onError(.notPoweredOn(peripheral.state))
            @unknown default:
                onError(.unknown)
            }
        case .notDetermined, .restricted, .denied:
            onError(.permissionsNotGranted(authorization))
        @unknown default:
            onError(.unknown)
        }
    }

    func handleDidAddService(
        for peripheral: any PeripheralManagerProtocol,
        service: CBService,
        error: (any Error)?
    ) {
        if let error {
            let peripheralError = PeripheralError.addServiceError(error.localizedDescription)

            // Notify delegate of failure
            delegate?.peripheralSessionDidUpdateState(withError: peripheralError)
            return
        }
    
        // Notify delegate of success
        delegate?.peripheralSessionDidUpdateState(withError: nil)
        print("PeripheralManager did add service: \(service) for peripheral: \(peripheral)")
    }

    func handleDidSubscribe(
        for peripheral: any PeripheralManagerProtocol,
        central: any BluetoothCentralProtocol,
        to characteristic: CBCharacteristic
    ) {

        self.subscribedCentrals[characteristic]?.removeAll(where: { $0.identifier == central.identifier })

        if self.subscribedCentrals[characteristic] == nil {
            self.subscribedCentrals[characteristic] = []
        }
        self.subscribedCentrals[characteristic]?.append(central)
        print("PeripheralManager did subscribe to central: \(central) for peripheral: \(peripheral)")
    }

    func handleDidStartAdvertising(
        for peripheral: any PeripheralManagerProtocol,
        error: (any Error)?
    ) {
        if let error {
            onError(.startAdvertisingError(error.localizedDescription))
        } else {
            print("Advertising started: ", peripheral.isAdvertising)
            delegate?.peripheralSessionDidUpdateState(withError: nil)
        }
    }

    func handleDidReceiveWrite(
        for peripheral: any PeripheralManagerProtocol,
        with requests: [any ATTRequestProtocol]
    ) {
        guard let firstRequest = requests.first else {
            return
        }

        let stateUUID = CharacteristicType.state.uuid
        if firstRequest.characteristic.uuid == stateUUID &&
            firstRequest.value == ConnectionState.start.data {
            
            print("Start request received")
            peripheral.respond(to: firstRequest, withResult: .success)
        } else {
            // Fallback for unknown characteristics
            peripheral.respond(to: firstRequest, withResult: .requestNotSupported)
        }
    }
}

enum ConnectionState: UInt8 {
    case start = 0x01
    case end = 0x02

    var data: Data {
        Data([rawValue])
    }
}
