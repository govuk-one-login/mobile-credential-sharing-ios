import Foundation
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("SessionData Tests")
struct SessionDataTests {

    // MARK: - AC1: Instantiate SessionData with data only
    @Test("SessionData with data only holds the byte array")
    func sessionDataWithDataOnlyHoldsBytes() {
        let payload = Data([0x01, 0x02, 0x03])
        let sessionData = SessionData(data: payload)

        #expect(sessionData.data == payload)
        #expect(sessionData.status == nil)
    }

    @Test("SessionData with data only encodes to CBOR map containing only the 'data' key")
    func sessionDataWithDataOnlyEncodesToCBORWithDataKeyOnly() {
        let payload = Data([0x01, 0x02, 0x03])
        let sessionData = SessionData(data: payload)

        let cbor = sessionData.toCBOR()
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }

        #expect(map.count == 1)
        #expect(map[CBOR("data")] == .byteString([0x01, 0x02, 0x03]))
        #expect(map[CBOR("status")] == nil)
    }

    // MARK: - AC2: Instantiate SessionData with status only
    @Test("SessionData with status only holds the integer value")
    func sessionDataWithStatusOnlyHoldsValue() {
        let sessionData = SessionData(status: 20)

        #expect(sessionData.data == nil)
        #expect(sessionData.status == 20)
    }

    @Test("SessionData with status only encodes to CBOR map containing only the 'status' key")
    func sessionDataWithStatusOnlyEncodesToCBORWithStatusKeyOnly() {
        let sessionData = SessionData(status: 20)

        let cbor = sessionData.toCBOR()
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }

        #expect(map.count == 1)
        #expect(map[CBOR("status")] == .unsignedInt(20))
        #expect(map[CBOR("data")] == nil)
    }

    // MARK: - AC3: Instantiate SessionData with both data and status
    @Test("SessionData with both data and status holds both values")
    func sessionDataWithBothHoldsBothValues() {
        let payload = Data([0xAA, 0xBB])
        let sessionData = SessionData(data: payload, status: 20)

        #expect(sessionData.data == payload)
        #expect(sessionData.status == 20)
    }

    @Test("SessionData with both data and status encodes to CBOR map containing both keys")
    func sessionDataWithBothEncodesToCBORWithBothKeys() {
        let payload = Data([0xAA, 0xBB])
        let sessionData = SessionData(data: payload, status: 20)

        let cbor = sessionData.toCBOR()
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }

        #expect(map.count == 2)
        #expect(map[CBOR("data")] == .byteString([0xAA, 0xBB]))
        #expect(map[CBOR("status")] == .unsignedInt(20))
    }

    // MARK: - Edge case: empty SessionData
    @Test("SessionData with neither data nor status encodes to empty CBOR map")
    func sessionDataEmptyEncodesToEmptyCBORMap() {
        let sessionData = SessionData()

        let cbor = sessionData.toCBOR()
        guard case let .map(map) = cbor else {
            Issue.record("Expected CBOR map")
            return
        }

        #expect(map.isEmpty)
    }

    // MARK: - CBOR round-trip encoding
    @Test("SessionData encodes to valid CBOR bytes")
    func sessionDataEncodesToValidCBORBytes() {
        let sessionData = SessionData(status: 20)
        let encoded = Data(sessionData.encode(options: CBOROptions()))

        // Verify the encoded bytes can be decoded back
        let decoded = try? CBOR.decode([UInt8](encoded))
        #expect(decoded != nil)

        if case let .map(map) = decoded {
            #expect(map[CBOR("status")] == .unsignedInt(20))
        } else {
            Issue.record("Decoded CBOR should be a map")
        }
    }
}
