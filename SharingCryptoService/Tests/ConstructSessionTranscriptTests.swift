import CryptoKit
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("constructSessionTranscript tests")
struct ConstructSessionTranscriptTests {
    let sut: CryptoService
    let deviceEngagement: DeviceEngagement

    init() throws {
        let mockSessionDecryption = MockSessionDecryption()
        self.sut = CryptoService(sessionDecryption: mockSessionDecryption, sessionEncryption: MockSessionEncryption())
        // swiftlint:disable:next line_length
        self.deviceEngagement = try DeviceEngagement(from: "owBjMS4wAYIB2BhYS6QBAiABIVggYRjA9t1gxaLrXgGhwlicYZv0DiMcEk6XYsGRnrQFLtgiWCA2xjgQYWD3mVoyopVgQSxB-d20858IftBf1evzEkKjNAKBgwIBowD1AfQKUC7huHQAAUkksKGuXFLNBg8")
    }

    // MARK: - AC1: SessionTranscript array constructed successfully

    @Test("SessionTranscript array contains exactly 3 elements")
    func sessionTranscriptArrayContainsThreeElements() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        let context = try #require(session.cryptoContext)
        let transcriptBytes = try #require(context.sessionTranscriptBytes)
        let decoded = try #require(try CBOR.decode(transcriptBytes))

        guard case let .tagged(tag, .byteString(innerBytes)) = decoded else {
            Issue.record("Expected Tag 24 wrapping")
            return
        }
        #expect(tag == .encodedCBORDataItem)

        let inner = try #require(try CBOR.decode(innerBytes))
        guard case let .array(elements) = inner else {
            Issue.record("Expected SessionTranscript to be a CBOR array")
            return
        }
        #expect(elements.count == 3)
    }

    @Test("SessionTranscript index 0 is DeviceEngagementBytes")
    func sessionTranscriptIndexZeroIsDeviceEngagementBytes() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        let elements = try decodeSessionTranscriptArray(from: session)
        let expectedDeviceEngagementBytes = deviceEngagement.encode(options: CBOROptions())

        #expect(elements[0] == .tagged(.encodedCBORDataItem, .byteString(expectedDeviceEngagementBytes)))
    }

    @Test("SessionTranscript index 1 is EReaderKeyBytes")
    func sessionTranscriptIndexOneIsEReaderKeyBytes() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        let elements = try decodeSessionTranscriptArray(from: session)

        #expect(elements[1] == .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)))
    }

    @Test("SessionTranscript index 2 is null (QR handover)")
    func sessionTranscriptIndexTwoIsNull() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        let elements = try decodeSessionTranscriptArray(from: session)

        #expect(elements[2] == .null)
    }

    // MARK: - AC2: SessionTranscriptBytes encoded and tagged

    @Test("SessionTranscriptBytes is wrapped in CBOR Tag 24")
    func sessionTranscriptBytesWrappedInTag24() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        let transcriptBytes = try #require(session.cryptoContext?.sessionTranscriptBytes)
        let decoded = try #require(try CBOR.decode(transcriptBytes))

        guard case let .tagged(tag, .byteString(_)) = decoded else {
            Issue.record("Expected tagged byte string")
            return
        }
        #expect(tag == .encodedCBORDataItem)
    }

    @Test("SessionTranscriptBytes is stored in session cryptoContext")
    func sessionTranscriptBytesStoredInMemory() throws {
        let session = MockCryptoVerifierSession()
        let eReaderKeyBytes = P256.KeyAgreement.PrivateKey().publicKey.eReaderKeyBytes()
        session.cryptoContext = CryptoContext(deviceEngagement: deviceEngagement, eReaderKeyBytes: eReaderKeyBytes)

        try sut.constructSessionTranscript(in: session)

        #expect(session.cryptoContext?.sessionTranscriptBytes != nil)
        #expect(session.cryptoContext?.sessionTranscriptBytes?.isEmpty == false)
    }

    // MARK: - Helpers

    private func decodeSessionTranscriptArray(from session: MockCryptoVerifierSession) throws -> [CBOR] {
        let transcriptBytes = try #require(session.cryptoContext?.sessionTranscriptBytes)
        let decoded = try #require(try CBOR.decode(transcriptBytes))

        guard case let .tagged(_, .byteString(innerBytes)) = decoded else {
            Issue.record("Expected Tag 24 wrapping")
            return []
        }

        let inner = try #require(try CBOR.decode(innerBytes))
        guard case let .array(elements) = inner else {
            Issue.record("Expected CBOR array")
            return []
        }
        return elements
    }
}

private extension P256.KeyAgreement.PublicKey {
    func eReaderKeyBytes() -> [UInt8] {
        let eReaderKey = EReaderKey(publicKey: self)
        let encoded = eReaderKey.toCBOR(options: CBOROptions()).encode()
        return CBOR.tagged(.encodedCBORDataItem, .byteString(encoded)).encode()
    }
}
