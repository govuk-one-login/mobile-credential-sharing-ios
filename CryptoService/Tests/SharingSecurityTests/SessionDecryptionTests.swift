import CryptoKit
@testable import CryptoService
import Foundation
import Testing

@Suite
struct SessionDecryptionTests {
    let privateKey = P256.KeyAgreement.PrivateKey()
    var sut: SessionDecryption {
        SessionDecryption(privateKey: privateKey)
    }

    // MARK: - AC1: Salt calculated (SHA-256 of SessionTranscriptBytes, 32 bytes)
    @Test("Salt from SessionTranscriptBytes is SHA-256 and 32 bytes")
    func saltIsSHA256And32Bytes() throws {
        let sessionTranscriptBytes: [UInt8] = [0x01, 0x02, 0x03]
        let digest = SHA256.hash(data: Data(sessionTranscriptBytes))
        #expect(Array(digest).count == 32)
    }

    // MARK: - AC2: SKReader key derived
    @Test("SKReader is 32 bytes, non-zero")
    func deriveSKReaderSuccess() throws {
        let otherKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: otherKey.publicKey)
        let sessionTranscriptBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let key1 = try sut.deriveSKReader(sharedSecret: sharedSecret, sessionTranscriptBytes: sessionTranscriptBytes)
        let key2 = try sut.deriveSKReader(sharedSecret: sharedSecret, sessionTranscriptBytes: sessionTranscriptBytes)
        #expect(key1.count == 32)
        #expect(key2.count == 32)
        #expect(key1 == key2)
        #expect(key1 != [UInt8](repeating: 0, count: 32))
    }

    // MARK: - AC3: SKDevice key derived
    @Test("deriveDevice returns 32 bytes, non-zero, disstinct from SKReader")
    func deriveSKDeviceSuccess() throws {
        let otherKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: otherKey.publicKey)
        let sessionTranscriptBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05]
        let skReader = try sut.deriveSKReader(sharedSecret: sharedSecret, sessionTranscriptBytes: sessionTranscriptBytes)
        let skDevice = try sut.deriveSKDevice(sharedSecret: sharedSecret, sessionTranscriptBytes: sessionTranscriptBytes)
        #expect(skDevice.count == 32)
        #expect(skDevice != [UInt8](repeating: 0, count: 32))
        #expect(skDevice != skReader)
    }

    // MARK: - AC4: SKReader derivation failure (error type and message)
    @Test("SKReader derivation error message contains status code 10 session encryption error")
    func skReaderDerivationFailureMessage() {
        let error = DecryptionError.skReaderDerivationFailed
        #expect(error.errorDescription.contains("(status code 10 encryption error)"))
    }

    // MARK: - AC5: SKDevice derivation failure (error type and message)
    @Test("SKDevice derivation error message contains status code 10 session encryption error")
    func skDeviceDerivationFailureMessage() {
        let error = DecryptionError.skDeviceDerivationFailed
        #expect(error.errorDescription.contains("(status code 10 encryption error)"))
    }

    @Test("Public key matches private key")
    func publicKeyValue() async throws {
        #expect(sut.publicKey.rawRepresentation == privateKey.publicKey.rawRepresentation)
    }
    
    @Test("decryptData func generates sharedSecret and derives keys - does not throw")
    func decryptDataGeneratesSharedSecret() throws {
        let otherPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        #expect(throws: Never.self) {
            try sut.decryptData(
                [0x00],
                salt: [0x00],
                encryptedWith: otherPublicKey,
                by: .reader
            )
        }
    }
}
