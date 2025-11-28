@testable import Bluetooth
import CoreBluetooth
import Testing

@Suite("Characteristic Type Tests")
struct CharacteristicTypeTests {
    @Test("Uses the Service Charateristic UUIDs defined in ISO 18013-5 Spec")
    func serviceCharacteristicsUUIDs() {
        #expect(CharacteristicType.state.rawValue == "00000001-A123-48CE-896B-4C76973373E6")
        #expect(CharacteristicType.clientToServer.rawValue == "00000002-A123-48CE-896B-4C76973373E6")
        #expect(CharacteristicType.serverToClient.rawValue == "00000003-A123-48CE-896B-4C76973373E6")
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
