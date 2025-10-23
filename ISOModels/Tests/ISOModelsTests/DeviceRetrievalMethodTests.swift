@testable import ISOModels
import Foundation
import Testing

@Suite("DeviceRetrievalMethod tests")
struct DeviceRetrievalMethodTests {
    let sut = DeviceRetrievalMethod
        .bluetooth(
            .peripheralOnly(
                PeripheralMode(uuid: UUID(), address: "test")
            )
        )
    
    @Test("Type values are as defined in the ISO specification")
    func typeValueIsCorrect() async throws {
        #expect(sut.type == 2)
    }

    @Test("Version values are as defined in the ISO specification")
    func versionValueIsCorrect() async throws {
        #expect(sut.version == 1)
    }
}
