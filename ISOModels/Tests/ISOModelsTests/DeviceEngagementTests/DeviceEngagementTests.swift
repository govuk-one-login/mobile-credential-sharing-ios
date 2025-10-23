@testable import ISOModels
import Foundation
import Testing

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
}
