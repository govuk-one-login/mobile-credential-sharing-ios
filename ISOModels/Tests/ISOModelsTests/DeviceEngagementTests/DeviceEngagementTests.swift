@testable import ISOModels
import Testing

struct DeviceEngagementTests {
    @Test("Version value is 1.0 as defined in ISO 18013-5")
    func versionValue() {
        let sut = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite(identifier: 1),
                eDeviceKey: EDeviceKey(key: "123")
            ), deviceRetrievalMethods: [.bluetooth]
        )
        
        #expect(sut.version == "1.0")
    }
}

