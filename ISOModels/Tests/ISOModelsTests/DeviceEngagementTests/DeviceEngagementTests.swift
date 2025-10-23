import Foundation
@testable import ISOModels
import Testing
import SwiftCBOR

struct DeviceEngagementTests {
    
    let key = EDeviceKey(
        curve: .p256,
        xCoordinate: [], yCoordinate: []
    )
    
    @Test("Version value is 1.0 as defined in ISO 18013-5")
    func versionValue() {
        let sut = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite(identifier: 1),
                eDeviceKey: key,
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: UUID.init(),
                        address: "mock address"
                    )
                )
            )]
        )
        
        #expect(sut.version == "1.0")
    }
    
    @Test("Correctly encodes to CBOR with no device retrieval methods")
    func encodesToCBORNoRetrievalMethods() throws {
        let sut = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite(identifier: 1),
                eDeviceKey: key,
            ),
            deviceRetrievalMethods: []
        )
        
        #expect(
            sut.toCBOR(options: CBOROptions()) == [
                0: "1.0",
                1: [
                    1,
                    .tagged(
                        .encodedCBORDataItem,
                        .byteString(key.encode(options: CBOROptions()))
                    )
                ]
            ]
        )
    }
    
    @Test("Correctly encodes to CBOR with device retrieval methods")
    func encodesToCBORWithRetrievalMethods() throws {
        let method: DeviceRetrievalMethod = .bluetooth(
            .peripheralOnly(
                PeripheralMode(
                    uuid: UUID.init(),
                    address: "test"
                )
            )
        )
        let sut = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite(identifier: 1),
                eDeviceKey: key,
            ),
            deviceRetrievalMethods: [method]
        )
        
        let encodedDeviceEngagement = sut.toCBOR(options: CBOROptions())
        let encodedRetrievalMethod = method.toCBOR(options: CBOROptions())
        
        #expect(encodedDeviceEngagement == [
            0: "1.0",
            1: [1, .tagged(.encodedCBORDataItem, .byteString(key.encode(options: CBOROptions())))],
            2: [encodedRetrievalMethod]
        ])
    }
}
