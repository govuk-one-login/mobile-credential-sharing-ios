@testable import Bluetooth
import Testing

@Suite("Service Characteristics UUIDs Tests")
struct ServiceCharacteristicTests {
    @Test("Uses the Service Charateristic UUIDs defined in ISO 18013-5 Spec")
    func serviceCharacteristics() {
        #expect(ServiceCharacteristic.state.rawValue == "00000001-A123-48CE-896B-4C76973373E6")
        #expect(ServiceCharacteristic.clientToServer.rawValue == "00000002-A123-48CE-896B-4C76973373E6")
        #expect(ServiceCharacteristic.serverToClient.rawValue == "00000003-A123-48CE-896B-4C76973373E6")
    }
    
    @Test("Service Characteristics have mandatory properties defined in ISO 18013-5 Spec")
    func serviceCharacteristicProperties() {
        #expect(ServiceCharacteristic.state.properties == [.notify, .writeWithoutResponse])
        #expect(ServiceCharacteristic.clientToServer.properties == [.writeWithoutResponse])
        #expect(ServiceCharacteristic.serverToClient.properties == [.notify])
    }
}
