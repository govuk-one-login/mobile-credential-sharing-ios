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
    // swiftlint:disable:next line_length
    let validData: [UInt8] = [82, 173, 162, 172, 190, 182, 195, 144, 242, 202, 11, 198, 89, 180, 132, 103, 142, 185, 77, 212, 80, 116, 56, 106, 173, 236, 226, 55, 119, 180, 70, 6, 228, 46, 40, 70, 188, 46, 46, 227, 193, 232, 103, 177, 209, 104, 94, 65, 53, 74, 2, 26, 187, 15, 218, 54, 240, 156, 245, 213, 197, 27, 86, 29, 59, 228, 28, 147, 71, 174, 113, 207, 43, 73, 222, 157, 236, 123, 68, 4, 106, 176, 34, 71, 147, 27, 33, 12, 145, 87, 132, 12, 21, 20, 166, 2, 123, 8, 129, 7, 22, 173, 246, 25, 102, 52, 73, 121, 49, 74, 195, 174, 159, 64, 230, 110, 1, 92, 18, 84, 166, 132, 16, 139, 208, 147, 232, 119, 46, 195, 51, 251, 102, 63, 214, 128, 58, 240, 46, 161, 11, 219, 232, 58, 153, 159, 117, 181, 90, 24, 15, 135, 33, 57, 251, 87, 172, 4, 172, 213, 140, 161, 94, 202, 21, 12, 222, 28, 59, 132, 148, 1, 24, 139, 122, 48, 206, 136, 125, 215, 183, 27, 18, 237, 162, 252, 110, 198, 229, 35, 90, 108, 148, 152, 53, 31, 205, 48, 31, 34, 146, 164, 235, 186, 117, 85, 40, 92, 238, 132, 234, 217, 110, 241, 103, 123, 10, 248, 35, 159, 106, 122, 82, 175, 75, 136, 9, 177, 213, 42, 178, 26, 22, 44, 163, 26, 222, 33, 197, 123, 209, 217, 151, 10, 40, 50, 170, 196, 28, 125, 82, 209, 196, 254, 228, 238, 100, 3, 10, 33, 141, 245, 19, 99, 190, 112, 23, 146, 250, 108, 81, 92, 72, 155, 211, 157, 202, 214, 251, 164, 143, 29, 110, 177, 158, 156, 118, 149, 49, 163, 191, 153, 152, 163, 44, 1, 132, 19, 5, 242, 56, 68, 202, 61, 182, 161, 255, 13, 13, 145, 115, 67, 214, 47, 199, 42, 213, 142, 171, 1, 163, 25, 129, 22, 241, 150, 6, 96, 159, 148, 227, 94, 172, 183, 141, 35, 197, 156, 103, 133, 42, 54, 25, 21, 254, 135, 132, 140, 219, 165, 99, 12, 153, 250, 183, 26, 239, 247, 45, 19, 28, 244, 66, 101, 79, 119, 8, 236, 72, 33, 100, 22, 242, 217, 150, 207, 108, 249, 16, 18, 183, 113, 184, 137, 7, 177, 209, 98, 157, 250, 121, 67, 67, 230, 83, 195, 18, 7, 72, 46, 47, 102, 33, 205, 75, 93, 207, 59, 60, 50, 134, 37, 195, 63, 233, 139, 233, 156, 95, 38, 74, 38, 67, 21, 190, 65, 186, 253, 199, 38, 248, 188, 222, 89, 32, 222, 10, 113, 136, 77, 134, 10, 244, 76, 31, 241, 179, 215, 139, 46, 141, 114, 13, 133, 218, 229, 63, 234, 43, 63, 161, 128, 97, 98, 164, 190, 2, 208, 57, 86, 124, 94, 178, 65, 156, 42, 216, 121, 175, 72, 252, 183, 223, 85, 202, 148, 241, 176, 15, 98, 24, 127, 162, 50, 156, 130, 39, 170, 224, 19, 14, 192, 82, 202, 62, 33, 2, 229, 126, 114, 145, 27, 50, 140, 253, 207, 186, 175, 107, 147, 100, 102, 15, 97, 52, 21, 56, 38, 68, 195, 12, 11, 212, 226, 34, 197, 207, 148, 186, 90, 115, 103, 156, 83, 213, 206, 217, 92, 165, 7, 135, 194, 40, 154, 12, 23, 53, 131, 147, 193, 224, 242, 39, 35, 97, 0, 47, 185, 177, 96, 96, 104, 136, 165, 158, 247, 162, 195, 137, 246, 139, 124, 180, 36, 87, 45, 176, 38, 177, 124, 242, 189, 202, 252, 182, 124, 130, 146, 217, 43, 80, 5, 3, 86, 144, 10, 98, 168, 43, 22, 248, 84, 117, 144, 82, 176, 15, 15, 70, 115, 164, 98, 41, 244, 50, 87, 232, 232, 50, 84, 1, 179, 254, 204, 140, 109, 34, 88, 186, 247, 247, 194, 251, 186, 250, 179, 161, 182, 173, 237, 78, 206, 172, 30, 175, 213, 182, 17, 24, 223, 147, 188, 10, 98, 43, 3, 80, 79, 222, 71, 206, 187, 34, 78, 152, 61, 177, 38, 119, 227, 22, 194, 42, 174, 4, 45, 108, 228, 173, 174, 13, 139, 15, 64, 67, 123, 142, 26, 250, 8, 89, 201, 80, 27, 235, 99, 151, 68, 150, 133, 154, 96, 241, 16, 105, 177, 150, 91, 79, 250, 197, 119, 154, 150, 25, 31, 137, 234, 199, 202, 166, 136, 185, 230, 124]
    // swiftlint:disable:next line_length
    let validSessionTranscriptBytes: [UInt8] = [216, 24, 88, 201, 131, 216, 24, 88, 116, 163, 0, 99, 49, 46, 48, 1, 130, 1, 216, 24, 88, 75, 164, 1, 2, 32, 1, 33, 88, 32, 153, 89, 8, 28, 124, 87, 112, 161, 15, 87, 14, 97, 241, 76, 234, 219, 132, 108, 101, 108, 153, 139, 11, 180, 42, 153, 157, 90, 5, 212, 210, 191, 34, 88, 32, 6, 244, 176, 63, 25, 248, 7, 129, 32, 96, 17, 45, 11, 77, 9, 240, 74, 250, 83, 218, 101, 151, 74, 78, 170, 119, 9, 89, 49, 120, 0, 247, 2, 129, 131, 2, 1, 163, 0, 245, 1, 244, 10, 80, 6, 179, 132, 155, 39, 212, 71, 237, 153, 9, 115, 19, 220, 51, 86, 235, 216, 24, 88, 75, 164, 1, 2, 32, 1, 33, 88, 32, 96, 227, 57, 35, 133, 4, 31, 81, 64, 48, 81, 242, 65, 85, 49, 203, 86, 221, 63, 153, 156, 113, 104, 112, 19, 170, 198, 118, 139, 200, 24, 126, 34, 88, 32, 229, 141, 235, 143, 219, 233, 7, 247, 221, 83, 104, 36, 85, 81, 163, 71, 150, 247, 210, 33, 92, 68, 12, 51, 155, 176, 247, 182, 123, 236, 205, 250, 246]
        

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
                validData,
                salt: validSessionTranscriptBytes,
                encryptedWith: otherPublicKey,
                by: .reader
            )
        }
    }
    
    @Test("decrypt data successfully decrypts input and returns non nil data object")
    func decryptDataSuccesfullyDecryptsInput() async throws {
        let otherPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        
        #expect(try sut.decryptData(
            validData,
            salt: validSessionTranscriptBytes,
            encryptedWith: otherPublicKey,
            by: .reader
        ) != Data()
        )
    }
    @Test("decrypt data will throw a session decryption error if payload is too short")
    func decryptDataThrowsSessionDecryptionError() async throws {
        let otherPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        
        #expect(throws: DecryptionError.payloadTooShort) {
            try sut.decryptData(
                [UInt8](validData.prefix(10)),
                salt: validSessionTranscriptBytes,
                encryptedWith: otherPublicKey,
                by: .reader
            )
        }
    }
    
    @Test("decrypt data will throw if authentication tag is incorrect")
    func decryptDataThrowsDecryptionError() async throws {
        let otherPublicKey = P256.KeyAgreement.PrivateKey().publicKey
        
        #expect(throws: DecryptionError.authenticationError) {
            try sut.decryptData(
                [UInt8](validData.dropLast(1)),
                salt: validSessionTranscriptBytes,
                encryptedWith: otherPublicKey,
                by: .reader
            )
        }
    }
}
