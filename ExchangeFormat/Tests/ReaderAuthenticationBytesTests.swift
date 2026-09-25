import ExchangeFormat
import Foundation
import SwiftCBOR
import Testing

struct ReaderAuthenticationBytesTests {

    // Untagged SessionTranscript array [DeviceEngagement, EReaderKey, null]:
    //   83               array(3)
    //   D8 18 41 AA      tag(24) bstr(1) [0xAA]
    //   D8 18 41 BB      tag(24) bstr(1) [0xBB]
    //   F6               null (QR handover)
    private static let transcriptBytes = Data([
        0x83,
        0xD8, 0x18, 0x41, 0xAA,
        0xD8, 0x18, 0x41, 0xBB,
        0xF6
    ])

    // tag(24), bstr(1) [0x00].
    private static let itemsRequestData = Data([0xD8, 0x18, 0x41, 0x00])

    // Expected output, assembled here by hand from raw bytes.
    // Shape: Tag 24 wrapping array(3) of [label, transcript, request].
    private static let expectedBytes: Data = {
        let label: [UInt8] = [0x74] + Array("ReaderAuthentication".utf8) // tstr(20)
        let array: [UInt8] = [0x83] + label + [UInt8](transcriptBytes) + [UInt8](itemsRequestData)
        // Tag 24 (D8 18) + byte string of `array`. The 36-byte length uses the
        // 8-bit length form: 0x58 followed by the length.
        return Data([0xD8, 0x18, 0x58, UInt8(array.count)] + array)
    }()

    // MARK: - AC1: ReaderAuthenticationBytes is correctly constructed

    @Test("AC1: Produces the expected fixed vector")
    func fixedVector() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        let sut = try ReaderAuthenticationBytes(
            untaggedSessionTranscriptBytes: Self.transcriptBytes,
            itemsRequestBytes: irb
        )
        #expect(sut.bytes == Self.expectedBytes)
    }

    @Test("AC1: Result is a valid Tag 24 value wrapping a 3-element array")
    func structuralShape() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        let sut = try ReaderAuthenticationBytes(
            untaggedSessionTranscriptBytes: Self.transcriptBytes,
            itemsRequestBytes: irb
        )

        let outer = try #require(try CBOR.decode([UInt8](sut.bytes)))
        guard case let .tagged(tag, .byteString(innerBstr)) = outer else {
            Issue.record("Expected tagged byte string"); return
        }
        #expect(tag == .encodedCBORDataItem)

        let inner = try #require(try CBOR.decode(innerBstr))
        guard case let .array(elements) = inner else {
            Issue.record("Expected a 3-element array"); return
        }
        #expect(elements.count == 3)
        #expect(elements[0] == .utf8String("ReaderAuthentication"))
    }

    // MARK: - AC2: SessionTranscript contains the exact QR-session values
    //
    // The transcript's exact QR values (preserved DeviceEngagementBytes, reused
    // EReaderKeyBytes, null handover, untagged array) are proven in
    // ConstructSessionTranscriptTests. Here we prove the transcript is embedded
    // byte-for-byte, unchanged.

    @Test("AC2: Transcript bytes are embedded byte-for-byte")
    func transcriptPreservation() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        let sut = try ReaderAuthenticationBytes(
            untaggedSessionTranscriptBytes: Self.transcriptBytes,
            itemsRequestBytes: irb
        )

        // The transcript is spliced in verbatim after the fixed prefix:
        //   Tag 24 head + bstr header (4) + array(3) header (1) + label (21) = 26
        let raw = [UInt8](sut.bytes)
        let prefixLength = 4 + 1 + 21
        let transcriptStart = prefixLength
        let transcriptEnd = transcriptStart + Self.transcriptBytes.count
        #expect(Data(raw[transcriptStart..<transcriptEnd]) == Self.transcriptBytes)
    }

    // MARK: - AC3: ItemsRequestBytes is reused unchanged

    @Test("AC3: ItemsRequestBytes are embedded byte-for-byte")
    func requestPreservation() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        let sut = try ReaderAuthenticationBytes(
            untaggedSessionTranscriptBytes: Self.transcriptBytes,
            itemsRequestBytes: irb
        )

        // The request is spliced in verbatim after the fixed prefix and the
        // transcript: prefix (26) + transcript length.
        let raw = [UInt8](sut.bytes)
        let prefixLength = 4 + 1 + 21
        let requestStart = prefixLength + Self.transcriptBytes.count
        let requestEnd = requestStart + Self.itemsRequestData.count
        #expect(Data(raw[requestStart..<requestEnd]) == Self.itemsRequestData)
    }

    @Test("AC3: Construction leaves the supplied inputs unchanged")
    func inputsUnchangedAfterConstruction() throws {
        let transcript = Self.transcriptBytes
        let itemsData = Self.itemsRequestData
        let irb = try ItemsRequestBytes(from: itemsData)

        _ = try ReaderAuthenticationBytes(
            untaggedSessionTranscriptBytes: transcript,
            itemsRequestBytes: irb
        )

        #expect(transcript == Self.transcriptBytes)
        #expect(itemsData == Self.itemsRequestData)
        #expect(irb.bytes == Self.itemsRequestData)
    }

    // MARK: - Defensive validation (no corresponding ticket AC)

    @Test("Rejects ItemsRequestBytes that are not valid Tag 24")
    func invalidItemsRequest() {
        #expect(throws: ExchangeFormatError.invalidTag24) {
            try ItemsRequestBytes(from: Data([0x00]))
        }
    }

    @Test("Rejects transcript with trailing data")
    func transcriptTrailingData() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        var badTranscript = Self.transcriptBytes
        badTranscript.append(0xFF)
        #expect(throws: ExchangeFormatError.trailingData) {
            try ReaderAuthenticationBytes(
                untaggedSessionTranscriptBytes: badTranscript,
                itemsRequestBytes: irb
            )
        }
    }

    @Test("Rejects empty transcript")
    func emptyTranscript() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        #expect(throws: ExchangeFormatError.malformedStructure) {
            try ReaderAuthenticationBytes(
                untaggedSessionTranscriptBytes: Data(),
                itemsRequestBytes: irb
            )
        }
    }

    @Test("Rejects truncated transcript")
    func truncatedTranscript() throws {
        let irb = try ItemsRequestBytes(from: Self.itemsRequestData)
        #expect(throws: ExchangeFormatError.malformedStructure) {
            try ReaderAuthenticationBytes(
                untaggedSessionTranscriptBytes: Data([0x83]),
                itemsRequestBytes: irb
            )
        }
    }
}
