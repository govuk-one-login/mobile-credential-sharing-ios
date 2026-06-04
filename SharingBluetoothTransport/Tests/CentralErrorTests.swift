import CoreBluetooth
@testable import SharingBluetoothTransport
import Testing

@Suite("CentralError Tests")
struct CentralErrorTests {
    @Test("CentralError descriptions are correct")
    func centralErrorDescriptions() {
        #expect(
            CentralError.notPoweredOn(.poweredOff).errorDescription
                == "Bluetooth is not ready. Current state: Powered off."
        )
        #expect(
            CentralError.notPoweredOn(.resetting).errorDescription
                == "Bluetooth is not ready. Current state: Resetting."
        )
        #expect(
            CentralError.notPoweredOn(.unauthorized).errorDescription
                == "Bluetooth is not ready. Current state: Unauthorized."
        )
        #expect(
            CentralError.notPoweredOn(.unknown).errorDescription
                == "Bluetooth is not ready. Current state: Unknown."
        )
        #expect(
            CentralError.notPoweredOn(.unsupported).errorDescription
                == "Bluetooth is not ready. Current state: Unsupported."
        )
        #expect(
            CentralError.notPoweredOn(.poweredOn).errorDescription
                == "Bluetooth is not ready. Current state: Unknown."
        )
        #expect(
            CentralError.permissionsNotGranted(.denied).errorDescription
                == "App does not have the required Bluetooth permissions. Current state: Denied."
        )
        #expect(
            CentralError.permissionsNotGranted(.restricted).errorDescription
                == "App does not have the required Bluetooth permissions. Current state: Restricted."
        )
        #expect(
            CentralError.permissionsNotGranted(.notDetermined).errorDescription
                == "App does not have the required Bluetooth permissions. Current state: Not Determined."
        )
        #expect(
            CentralError.permissionsNotGranted(.allowedAlways).errorDescription
                == "App does not have the required Bluetooth permissions. Current state: Unknown."
        )
        #expect(
            CentralError.serviceUUIDNotSet.errorDescription == "serviceUUID not set on session"
        )
        #expect(
            CentralError.unknown.errorDescription == "An unknown error has occured."
        )
    }
}
