@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("IssuerSignedItem Tests")
struct IssuerSignedItemTests {

    // MARK: - init(rawCBOR:) success

    @Test("init(rawCBOR:) decodes all fields from valid Tag 24 CBOR")
    func rawCBORDecodesAllFields() throws {
        // Given
        let innerMap = CBOR.map([
            .utf8String("digestID"): .unsignedInt(5),
            .utf8String("random"): .byteString([0xAA, 0xBB]),
            .utf8String("elementIdentifier"): .utf8String("family_name"),
            .utf8String("elementValue"): .utf8String("Smith")
        ])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))

        // When
        let item = try IssuerSignedItem(rawCBOR: rawCBOR)

        // Then
        #expect(item.elementIdentifier == "family_name")
        #expect(item.elementValue == .utf8String("Smith"))
    }

    @Test("init(rawCBOR:) decodes boolean element value")
    func rawCBORDecodesBooleanValue() throws {
        // Given
        let innerMap = CBOR.map([
            .utf8String("digestID"): .unsignedInt(2),
            .utf8String("random"): .byteString([0x01]),
            .utf8String("elementIdentifier"): .utf8String("age_over_18"),
            .utf8String("elementValue"): .boolean(true)
        ])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))

        // When
        let item = try IssuerSignedItem(rawCBOR: rawCBOR)

        // Then
        #expect(item.elementIdentifier == "age_over_18")
        #expect(item.elementValue == .boolean(true))
    }

    @Test("init(rawCBOR:) defaults digestID to 0 when missing from map")
    func rawCBORDefaultsDigestID() throws {
        // Given — valid Tag 24 with inner map missing digestID
        let innerMap = CBOR.map([
            .utf8String("random"): .byteString([0x01]),
            .utf8String("elementIdentifier"): .utf8String("given_name"),
            .utf8String("elementValue"): .utf8String("Jane")
        ])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))

        // When
        let item = try IssuerSignedItem(rawCBOR: rawCBOR)

        // Then
        #expect(item.elementIdentifier == "given_name")
        #expect(item.elementValue == .utf8String("Jane"))
    }

    @Test("init(rawCBOR:) defaults elementValue to null when missing from map")
    func rawCBORDefaultsElementValue() throws {
        // Given
        let innerMap = CBOR.map([
            .utf8String("digestID"): .unsignedInt(1),
            .utf8String("random"): .byteString([0x01]),
            .utf8String("elementIdentifier"): .utf8String("portrait")
        ])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))

        // When
        let item = try IssuerSignedItem(rawCBOR: rawCBOR)

        // Then
        #expect(item.elementIdentifier == "portrait")
        #expect(item.elementValue == .null)
    }

    // MARK: - init(rawCBOR:) throws

    @Test("init(rawCBOR:) throws when CBOR is not Tag 24")
    func rawCBORThrowsWhenNotTag24() {
        let rawCBOR = CBOR.utf8String("not a tag")

        #expect(throws: DeviceResponseError.self) {
            try IssuerSignedItem(rawCBOR: rawCBOR)
        }
    }

    @Test("init(rawCBOR:) throws when Tag 24 contains invalid inner bytes")
    func rawCBORThrowsWhenInnerBytesInvalid() {
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString([0xFF, 0xFF, 0xFF]))

        #expect(throws: DeviceResponseError.self) {
            try IssuerSignedItem(rawCBOR: rawCBOR)
        }
    }

    @Test("init(rawCBOR:) throws when inner CBOR is not a map")
    func rawCBORThrowsWhenInnerNotMap() {
        let innerArray = CBOR.array([.utf8String("not"), .utf8String("a map")])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerArray.encode()))

        #expect(throws: DeviceResponseError.self) {
            try IssuerSignedItem(rawCBOR: rawCBOR)
        }
    }

    // MARK: - toCBOR preserves original bytes

    @Test("toCBOR returns original CBOR when constructed from rawCBOR")
    func toCBORPreservesOriginal() throws {
        // Given
        let innerMap = CBOR.map([
            .utf8String("digestID"): .unsignedInt(3),
            .utf8String("random"): .byteString([0x01, 0x02]),
            .utf8String("elementIdentifier"): .utf8String("family_name"),
            .utf8String("elementValue"): .utf8String("Doe")
        ])
        let rawCBOR = CBOR.tagged(.encodedCBORDataItem, .byteString(innerMap.encode()))

        // When
        let item = try IssuerSignedItem(rawCBOR: rawCBOR)

        // Then
        #expect(item.toCBOR() == rawCBOR)
    }
}
