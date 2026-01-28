import Foundation
@testable import ISOModels
import SwiftCBOR
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
                cipherSuiteIdentifier: .iso18013,
                eDeviceKey: key,
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: UUID.init()
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
                cipherSuiteIdentifier: .iso18013,
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
                    uuid: UUID.init()
                )
            )
        )
        let sut = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: .iso18013,
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
    
    
    @Test("Decoding a good QR URL to a Device Engagement object")
    func decodeQRStringToCBORMap() throws {
        // swiftlint:disable:next line_length
        let exampleString: String = "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        
        let sut = try DeviceEngagement(from: exampleString)
        
        // security object
        let cipherSuiteIdentifier = 24
        let xCoord: [UInt8] = [85, 251, 225, 132, 37, 83, 78, 205, 109, 47, 238, 154, 65, 233, 177, 121, 192, 177, 252, 77, 98, 47, 225, 124, 190, 114, 161, 150, 88, 189, 104, 5]
        let yCoord: [UInt8] = [127, 14, 254, 2, 76, 187, 208, 223, 44, 19, 41, 11, 132, 160, 52, 153, 247, 9, 195, 171, 150, 133, 36, 98, 223, 36, 83, 64, 176, 234, 178, 229]
        let curve = Curve.p256
        
        // retrieval ojbect
        guard let uuid = UUID(uuidString: "6CAA059E-041A-453F-9029-8698BF559809") else { return }
        
        // Device engagement object
        let version = "1.0"
        
        // now to check it's all correct
        #expect(sut.version == version)
        #expect(sut.security.cipherSuiteIdentifier.identifier == cipherSuiteIdentifier)
        #expect(sut.security.eDeviceKey.curve == curve)
        #expect(sut.security.eDeviceKey.xCoordinate == xCoord)
        #expect(sut.security.eDeviceKey.yCoordinate == yCoord)
        
        guard let sutDeviceRetrievalMethods = sut.deviceRetrievalMethods else { return }
        #expect(sutDeviceRetrievalMethods[0].type == 2)
        #expect(sutDeviceRetrievalMethods[0].version == 1)
        
        guard case .bluetooth(let BLEDeviceRetrievalMethodOptions) = sutDeviceRetrievalMethods[0] else {
            return
        }
        guard case .peripheralOnly(let peripheralMode) = BLEDeviceRetrievalMethodOptions else {
            return
        }
        #expect(peripheralMode.uuid == uuid)
        #expect(peripheralMode.address == nil)
    }
    
    @Test("Decoding a bad QR URL thows .requestWasIncorrectlyStructured")
    func decodeBadQRurl() throws {
        // swiftlint:disable:next line_length
        let badQRurlString = "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmLmAk"
        
        #expect(throws: DeviceEngagementError.requestWasIncorrectlyStructured) {
            try DeviceEngagement(from: badQRurlString)
        }
    }
    
    @Test("Decoding a QR URL that is missing a version throws .noVersion error")
    func decodeQRurlWithoutVersion() throws {
        // swiftlint:disable:next line_length
        let missingVersionString = "owBgAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        #expect(throws: DeviceEngagementError.noVersion) {
            try DeviceEngagement(from: missingVersionString)
        }
    }
    
    @Test("Decoding a QR URL that is missing its security throws .noSecurity error")
    func decodeQRurlWithoutSecurity() throws {
        let missingSecurityString = "owBjMS4wAYACgYMCAaMA9QH0ClBsqgWeBBpFP5Aphpi_VZgJ"
        #expect(throws: DeviceEngagementError.noSecurity) {
            try DeviceEngagement(from: missingSecurityString)
        }
    }
    
    @Test("Decoding a QR URL that is missing its retrieval methods throws .noRetrievalMethods error")
    func decodeQRurlWithNoRetreivalMethods() throws {
        let noRetreivalMethodsString = "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKA"
        #expect(throws: DeviceEngagementError.noRetrievalMethods) {
            try DeviceEngagement(from: noRetreivalMethodsString)
        }
    }
    
    @Test("Decoding a QR URL that contains an incorrect version (0.1) throws .incorrectVersion error")
    func decodeQRurlWithWrongVersion() throws {
        // swiftlint:disable:next line_length
        let wrongVersionString = "owBjMC4xAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        
        #expect(throws: DeviceEngagementError.incorrectVersion) {
            try DeviceEngagement(from: wrongVersionString)
        }
    }
}
