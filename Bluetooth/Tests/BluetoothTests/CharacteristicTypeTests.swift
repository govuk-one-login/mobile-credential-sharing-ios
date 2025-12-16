import CoreBluetooth
import Testing

@testable import Bluetooth

@Suite("Characteristic Type Tests")
struct CharacteristicTypeTests {
    @Test(
        "Uses the Service Characteristic UUIDs defined in ISO 18013-5 Spec",
        arguments: [
            (CharacteristicType.state, "00000001-A123-48CE-896B-4C76973373E6"),
            (.clientToServer, "00000002-A123-48CE-896B-4C76973373E6"),
            (.serverToClient, "00000003-A123-48CE-896B-4C76973373E6"),
        ]
    )
    func serviceCharacteristicsUUIDs(type: CharacteristicType, expectedUUID: String) {
        #expect(type.rawValue == expectedUUID)
        #expect(type.uuid == CBUUID(string: expectedUUID))
    }

    @Test("Characteristic Types have mandatory properties defined in ISO 18013-5 Spec")
    func characteristicProperties() {
        #expect(CharacteristicType.state.properties == [.notify, .writeWithoutResponse])
        #expect(CharacteristicType.clientToServer.properties == [.writeWithoutResponse])
        #expect(CharacteristicType.serverToClient.properties == [.notify])
    }

    @Test("CBMutableCharacteristic successfully initialises")
    func cBMutableCharacteristicInit() {
        let characteristic = CBMutableCharacteristic(characteristic: CharacteristicType.state)

        #expect(characteristic.uuid == CBUUID(string: CharacteristicType.state.rawValue))
        #expect(characteristic.properties == CharacteristicType.state.properties)
        #expect(characteristic.permissions == [.readable, .writeable])
    }
}
