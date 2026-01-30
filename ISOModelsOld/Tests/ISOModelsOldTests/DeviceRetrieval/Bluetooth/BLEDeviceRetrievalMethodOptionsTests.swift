import Foundation
@testable import ISOModelsOld
import SwiftCBOR
import Testing

struct BLEDeviceRetrievalMethodOptionsTests {
    @Test("Encode peripheral only - contains the correct values")
    func testPeripheralOnly() throws {
        let uuid = UUID()

        let options = BLEDeviceRetrievalMethodOptions.peripheralOnly(
            PeripheralMode(uuid: uuid),
        )

        #expect(
            options.toCBOR(options: CBOROptions()) ==
            [
                0: true,
                1: false,
                10: .byteString([UInt8](uuid.data))
            ]
        )
    }

    @Test("Encode central only - contains the correct values")
    func testCentralOnly() throws {
        let uuid = UUID()
        let options = BLEDeviceRetrievalMethodOptions.centralOnly(
            CentralMode(uuid: uuid)
        )

        #expect(
            options.toCBOR(options: CBOROptions()) ==
            [
                0: false,
                1: true,
                11: .byteString([UInt8](uuid.data))
            ]
        )
    }

    @Test("Encode central or peripheral - contains the correct values")
    func testEitherMode() throws {
        let peripheralUUID = UUID()
        let centralUUID = UUID()

        let options = BLEDeviceRetrievalMethodOptions.either(
            PeripheralMode(uuid: peripheralUUID),
            CentralMode(uuid: centralUUID)
        )

        #expect(
            options.toCBOR(options: CBOROptions()) ==
            [
                0: true,
                1: true,
                10: .byteString([UInt8](peripheralUUID.data)),
                11: .byteString([UInt8](centralUUID.data))
            ]
        )
    }
}
