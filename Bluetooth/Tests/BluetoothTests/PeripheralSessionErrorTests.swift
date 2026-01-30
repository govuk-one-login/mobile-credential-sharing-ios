import CoreBluetooth
import Testing

@testable import Bluetooth

@Suite("PeripheralSessionError Tests")
struct PeripheralSessionErrorTests {
    @Test("PeripheralError descriptions are correct")
    func peripheralErrorDescriptions() {
        for error in [
            PeripheralError.notPoweredOn(CBManagerState.poweredOff),
            .addServiceError("service"),
            .permissionsNotGranted(CBManagerAuthorization.denied),
            .startAdvertisingError("advertising"),
            .clientToServerError("client"),
            .connectionTerminated,
            .failedToNotifyEnd,
            .unknown
        ] {
            switch error {
            case .notPoweredOn:
                #expect(
                    error.errorDescription == "Bluetooth is not ready. Current state: \(error.poweredOnState!)."
                )
            case .permissionsNotGranted:
                #expect(
                    error.errorDescription
                        == "App does not have the required Bluetooth permissions. Current state: \(error.permissionState!)."
                )
            case .addServiceError(let description):
                #expect(
                    error.errorDescription == "Failed to add service: \(description)."
                )
            case .startAdvertisingError(let description):
                #expect(
                    error.errorDescription == "Failed to start advertising: \(description)."
                )
            case .clientToServerError(let description):
                #expect(
                    error.errorDescription == "Client2Server message receipt failed: \(description)."
                )
            case .connectionTerminated:
                #expect(error.errorDescription == "Bluetooth disconnected unexpectedly.")
            case .failedToNotifyEnd:
                #expect(error.errorDescription == "Failed to notify GATT end command.")
            case .unknown:
                #expect(error.errorDescription == "An unknown error has occured.")
            }
        }
    }
}
