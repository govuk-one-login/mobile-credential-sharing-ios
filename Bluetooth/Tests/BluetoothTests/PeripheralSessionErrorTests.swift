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
            .sessionEstablishmentError("session"),
            .connectionTerminated,
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
            case .sessionEstablishmentError(let description):
                #expect(
                    error.errorDescription == "Session establishment failed: \(description)."
                )
            case .connectionTerminated:
                #expect(error.errorDescription == "Bluetooth disconnected unexpectedly.")
            case .unknown:
                #expect(error.errorDescription == "An unknown error has occured.")
            }
        }
    }
}
