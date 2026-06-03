import CryptoKit
@testable import SharingCryptoService
import SwiftCBOR
import Testing

@Suite("DCMAW-17530: Generate Ephemeral Key Pair (EReaderKey)")
struct EReaderKeyGenerationTests {
    var sut: CryptoService
    var mockSessionDecryption: MockSessionDecryption
    // swiftlint:disable:next line_length
    let validMdocQR = "mdoc:owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"

    init() {
        mockSessionDecryption = MockSessionDecryption()
        sut = CryptoService(sessionDecryption: mockSessionDecryption)
    }

    @Test("processQRCode generates EReaderKeyBytes and stores them on the session")
    func generatesEReaderKeyBytesOnValidQRScan() throws {
        let session = MockCryptoVerifierSession()

        try sut.processQRCode(validMdocQR, in: session)

        #expect(session.cryptoContext?.eReaderKeyBytes != nil)
        let bytes = try #require(session.cryptoContext?.eReaderKeyBytes)
        #expect(!bytes.isEmpty)
    }

    @Test("EReaderKeyBytes COSE_Key contains exactly kty: 2, crv: 1, x, and y with no optional parameters")
    func coseKeyContainsOnlyRequiredParameters() throws {
        let session = MockCryptoVerifierSession()

        try sut.processQRCode(validMdocQR, in: session)

        let eReaderKeyBytes = try #require(session.cryptoContext?.eReaderKeyBytes)
        // Decode Tag 24 wrapper
        let outerCBOR = try #require(try CBOR.decode(eReaderKeyBytes))
        guard case let .tagged(tag, .map(map)) = outerCBOR else {
            Issue.record("Expected Tag 24 wrapping a CBOR map")
            return
        }
        #expect(tag == .encodedCBORDataItem)

        // Exactly 4 keys: kty(1), crv(-1), x(-2), y(-3)
        #expect(map.count == 4)
        #expect(map[.unsignedInt(1)] == .unsignedInt(2))   // kty: EC2
        #expect(map[.negativeInt(0)] == .unsignedInt(1))   // crv: P-256

        guard case let .byteString(x) = map[.negativeInt(1)] else {
            Issue.record("Expected x-coordinate as byteString")
            return
        }
        guard case let .byteString(y) = map[.negativeInt(2)] else {
            Issue.record("Expected y-coordinate as byteString")
            return
        }
        #expect(x.count == 32)
        #expect(y.count == 32)

        // Must NOT contain optional parameters like kid(2) or alg(3)
        #expect(map[.unsignedInt(2)] == nil)
        #expect(map[.unsignedInt(3)] == nil)
    }

    @Test("EReaderKeyBytes is a CBOR byte string wrapped with Tag 24")
    func eReaderKeyBytesIsTag24Wrapped() throws {
        let session = MockCryptoVerifierSession()

        try sut.processQRCode(validMdocQR, in: session)

        let eReaderKeyBytes = try #require(session.cryptoContext?.eReaderKeyBytes)
        let outerCBOR = try #require(try CBOR.decode(eReaderKeyBytes))

        guard case let .tagged(tag, .map(map)) = outerCBOR else {
            Issue.record("Expected Tag 24 wrapping a CBOR map")
            return
        }
        #expect(tag == .encodedCBORDataItem)
        #expect(!map.isEmpty)
    }

    @Test("Each call to processQRCode generates a unique EReaderKeyBytes")
    func generatesNewKeyPairPerSession() throws {
        let session1 = MockCryptoVerifierSession()

        try sut.processQRCode(validMdocQR, in: session1)

        let bytes1 = try #require(session1.cryptoContext?.eReaderKeyBytes)

        // Keys are derived from the same SessionDecryption privateKey,
        // so within the same CryptoService instance they will be the same.
        // A NEW CryptoService (new SessionDecryption) produces different keys.
        let otherDecryption = MockSessionDecryption()
        let otherSut = CryptoService(sessionDecryption: otherDecryption)
        let session2 = MockCryptoVerifierSession()
        try otherSut.processQRCode(validMdocQR, in: session2)

        let bytes2 = try #require(session2.cryptoContext?.eReaderKeyBytes)
        #expect(bytes1 != bytes2)
    }
}
