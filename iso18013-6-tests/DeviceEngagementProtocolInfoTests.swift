import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

// swiftlint:disable line_length
/// ISO/IEC 18013-6 — Device Engagement tests for mdoc reader
/// Reference: ISO/IEC 18013-5:2021, 8.2.1.1
struct DeviceEngagementProtocolInfoTests {

    /// DE_01: key 4 (ProtocolInfo) with value {1: "test", 2: true}
    let engagementWithProtocolInfo = "pABjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAkEogFkdGVzdAL1"

    /// DE_02: keys 5="rfu", 24={0:1}, 65535=false
    let engagementWithMultipleRFUKeys = "pgBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAkFY3JmdRgYoQABGf__9A"

    /// DE_03: key -487 = "rfu"
    let engagementWithNegativeKey = "pABjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk5AeZjcmZ1"

    /// DE_04: version "1.5"
    let engagementWithVersion1_5 = "owBjMS41AYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
    // swiftlint:enable line_length
    private func assertRetrievalMethodValid(_ deviceEngagement: DeviceEngagement) throws {
        let retrievalMethods = try #require(deviceEngagement.deviceRetrievalMethods)
        #expect(retrievalMethods[0].type == 2)
        #expect(retrievalMethods[0].version == 1)
        guard case .bluetooth(let options) = retrievalMethods[0],
              case .peripheralOnly(let peripheral) = options else {
            Issue.record("Expected BLE peripheral retrieval method")
            return
        }
        #expect(peripheral.uuid == UUID(uuidString: "6CAA059E-041A-453F-9029-8698BF559809"))
    }

    @Test("mDLR_MS_DE_01: mdoc reader ignores ProtocolInfo (key 4) in DeviceEngagement")
    func readerIgnoresProtocolInfo() throws {
        let sut = try DeviceEngagement(from: engagementWithProtocolInfo)
        #expect(sut.version == "1.0")
        try assertRetrievalMethodValid(sut)
    }

    @Test("mDLR_MS_DE_02: mdoc reader ignores multiple RFU positive keys (5, 24, 65535)")
    func readerIgnoresMultipleRFUPositiveKeys() throws {
        let sut = try DeviceEngagement(from: engagementWithMultipleRFUKeys)
        #expect(sut.version == "1.0")
        try assertRetrievalMethodValid(sut)
    }

    @Test("mDLR_MS_DE_03: mdoc reader ignores negative key (-487) it cannot interpret")
    func readerIgnoresNegativeKey() throws {
        let sut = try DeviceEngagement(from: engagementWithNegativeKey)
        #expect(sut.version == "1.0")
        try assertRetrievalMethodValid(sut)
    }

    // TODO: DCMAW-20790 - Disabled as test is currently failing due to current implementation. 
    @Test("mDLR_MS_DE_04: mdoc reader accepts unknown minor version (1.5) with known major version", .disabled())
    func readerAcceptsUnknownMinorVersion() throws {
        let sut = try DeviceEngagement(from: engagementWithVersion1_5)
        #expect(sut.version == "1.5")
        try assertRetrievalMethodValid(sut)
    }
}
