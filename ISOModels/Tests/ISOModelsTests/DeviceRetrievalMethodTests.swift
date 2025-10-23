@testable import ISOModels
import Foundation
import Testing

@Suite("DeviceRetrievalMethod tests")
struct DeviceRetrievalMethodTests {
    @Test("Type values are as defined in the ISO specification")
    func typeValueIsCorrect() async throws {
        #expect(
            DeviceRetrievalMethod
                .bluetooth(
                    .peripheralOnly(
                        PeripheralMode(uuid: UUID(), address: "test")
                    )
                ).type == 2
        )
    }

    @Test("Version values are as defined in the ISO specification")
    func versionValueIsCorrect() async throws {
        #expect(DeviceRetrievalMethod
            .bluetooth(
                .peripheralOnly(
                    PeripheralMode(uuid: UUID(), address: "test")
                )
            ).version == 1)
    }
}
