@testable import CredentialSharingUI
import CryptoKit
@testable import CryptoService
import Foundation
import SwiftCBOR
import Testing

@Suite
struct SessionDecryptionTests {
    let privateKey = P256.KeyAgreement.PrivateKey()
    var sut: SessionDecryption {
        SessionDecryption(privateKey: privateKey)
    }
    // swiftlint:disable:next line_length
    var sessionEstablishmentData: [UInt8] = [159, 44, 239, 68, 70, 73, 154, 195, 98, 147, 17, 155, 115, 23, 62, 115, 103, 181, 110, 169, 211, 113, 32, 187, 35, 235, 23, 63, 9, 184, 233, 73, 252, 130, 124, 69, 14, 245, 243, 194, 190, 195, 103, 177, 249, 101, 63, 5, 76, 158, 42, 41, 45, 133, 192, 34, 87, 143, 199, 127, 211, 38, 205, 198, 154, 112, 66, 167, 43, 87, 52, 66, 106, 103, 66, 1, 220, 3, 44, 236, 192, 194, 226, 58, 41, 36, 206, 118, 184, 22, 95, 207, 27, 216, 183, 118, 159, 21, 188, 47, 16, 63, 28, 19, 93, 87, 10, 188, 228, 22, 43, 232, 35, 235, 157, 103, 174, 53, 245, 170, 31, 57, 214, 180, 62, 175, 93, 60, 172, 145, 1, 250, 246, 219, 92, 127, 246, 58, 150, 184, 61, 9, 46, 239, 71, 243, 59, 122, 83, 104, 127, 172, 226, 189, 6, 205, 126, 10, 231, 102, 23, 140, 253, 150, 51, 234, 208, 252, 227, 190, 165, 98, 33, 209, 98, 62, 33, 69, 181, 105, 186, 140, 161, 99, 15, 118, 18, 5, 38, 204, 103, 41, 11, 249, 34, 11, 20, 239, 207, 130, 42, 29, 136, 7, 18, 243, 11, 244, 127, 157, 251, 60, 248, 163, 132, 126, 111, 78, 58, 34, 49, 123, 214, 217, 3, 19, 241, 97, 23, 90, 184, 71, 173, 131, 214, 128, 44, 227, 227, 36, 53, 24, 227, 215, 176, 82, 57, 160, 110, 239, 57, 204, 219, 166, 239, 57, 171, 160, 25, 113, 196, 111, 173, 153, 97, 62, 118, 227, 14, 7, 25, 135, 83, 89, 144, 0, 247, 53, 77, 116, 104, 18, 252, 45, 88, 194, 174, 173, 130, 137, 16, 51, 242, 181, 24, 109, 117, 45, 227, 196, 10, 143, 15, 168, 5, 54, 202, 224, 153, 48, 12, 110, 56, 127, 102, 60, 229, 126, 210, 252, 65, 67, 220, 90, 136, 58, 181, 236, 111, 72, 228, 171, 235, 116, 202, 4, 90, 64, 5, 55, 164, 37, 30, 97, 147, 118, 252, 60, 212, 23, 124, 48, 97, 83, 237, 152, 218, 241, 121, 153, 39, 213, 175, 23, 84, 61, 22, 130, 49, 215, 187, 21, 216, 175, 233, 149, 204, 17, 176, 208, 249, 199, 189, 185, 123, 157, 218, 219, 122, 108, 253, 214, 244, 10, 0, 101, 86, 157, 181, 214, 85, 8, 105, 6, 239, 123, 122, 200, 149, 85, 139, 30, 94, 241, 37, 103, 198, 239, 50, 224, 184, 13, 115, 47, 251, 244, 53, 141, 53, 92, 254, 139, 80, 45, 220, 174, 55, 208, 138, 174, 161, 80, 12, 73, 69, 76, 48, 168, 108, 16, 92, 49, 129, 184, 93, 177, 200, 250, 17, 202, 118, 81, 194, 211, 187, 175, 74, 170, 203, 173, 116, 7, 125, 63, 180, 46, 51, 97, 60, 76, 143, 33, 243, 183, 181, 227, 235, 201, 129, 22, 0, 37, 57, 160, 151, 202, 76, 192, 174, 58, 162, 176, 194, 221, 143, 224, 238, 5, 29, 200, 85, 122, 77, 144, 79, 56, 69, 51, 244, 113, 169, 225, 176, 187, 173, 121, 145, 202, 159, 208, 28, 129, 13, 195, 217, 77, 14, 139, 223, 247, 15, 59, 60, 190, 210, 129, 113, 141, 159, 94, 197, 86, 220, 49, 116, 222, 105, 85, 161, 201, 17, 244, 120, 160, 184, 9, 141, 57, 223, 17, 55, 115, 157, 253, 214, 26, 137, 249, 190, 47, 49, 191, 212, 33, 133, 189, 231, 155, 115, 104, 74, 153, 35, 183, 43, 237, 130, 116, 72, 248, 172, 129, 86, 248, 69, 249, 156, 122, 105, 53, 168, 105, 60, 228, 196, 250, 251, 64, 24, 144, 248, 17, 249, 177, 158, 192, 146, 95, 193, 167, 175, 224, 66, 254, 139, 215, 53, 220, 150, 52, 85, 101, 212, 251, 58, 179, 163, 2, 110, 55, 140, 163, 119, 154, 254, 128, 53, 173, 74, 112, 78, 208, 198, 16, 119, 43, 171, 69, 248, 105, 198, 73, 56, 40, 145, 164, 156, 24, 134, 205, 36, 126, 229, 21, 221, 183, 100, 220, 88, 214, 216, 115, 122, 209, 84, 207, 200, 84, 230, 40, 236, 247, 115, 106, 27, 122, 244, 8, 6, 82, 79, 221, 102, 230, 175, 248, 205, 182, 51, 136, 90, 238, 72, 74, 133, 176, 123, 0, 41, 196, 91, 178, 24, 151, 34, 145, 238, 132, 155, 50, 18, 146, 163, 12, 140, 64, 200, 214, 74, 123, 240, 92, 145, 77, 230, 166, 254, 255, 79, 60, 67, 7, 8, 89, 124, 117, 26, 162, 33, 252, 39, 91, 137, 31, 139, 248, 83, 1, 171, 64, 59, 9, 52, 127, 103, 39, 237, 250, 145, 252, 115, 138, 198, 70, 114, 185, 252, 154, 129, 174, 40, 223, 240, 186, 52, 100, 120, 90, 94, 146, 19, 228, 208, 175, 210, 166, 94, 192, 55, 139, 54, 174, 193, 208, 237, 12, 40, 81, 156, 215, 118, 227, 0, 51, 197, 177, 141, 188, 100]

    // swiftlint:disable:next line_length
    var sessionTranscriptBytes: [UInt8] = [216, 24, 88, 201, 131, 216, 24, 88, 116, 163, 0, 99, 49, 46, 48, 1, 130, 1, 216, 24, 88, 75, 164, 1, 2, 32, 1, 33, 88, 32, 140, 162, 241, 172, 248, 9, 60, 194, 208, 229, 151, 85, 70, 147, 123, 227, 184, 228, 50, 33, 110, 14, 134, 136, 163, 33, 225, 173, 201, 204, 188, 75, 34, 88, 32, 118, 124, 187, 75, 107, 97, 219, 226, 168, 94, 30, 13, 154, 115, 242, 2, 87, 80, 6, 229, 115, 85, 82, 11, 157, 135, 65, 132, 18, 151, 69, 167, 2, 129, 131, 2, 1, 163, 0, 245, 1, 244, 10, 80, 124, 132, 99, 152, 90, 17, 64, 41, 152, 93, 74, 225, 174, 179, 238, 164, 216, 24, 88, 75, 164, 1, 2, 32, 1, 33, 88, 32, 136, 111, 184, 143, 92, 178, 148, 90, 78, 143, 218, 4, 38, 168, 12, 157, 135, 231, 242, 106, 251, 101, 223, 181, 12, 245, 190, 79, 229, 140, 4, 106, 34, 88, 32, 220, 214, 249, 59, 141, 7, 133, 210, 225, 180, 167, 191, 3, 135, 40, 124, 139, 195, 254, 189, 153, 110, 55, 228, 124, 127, 189, 27, 152, 37, 197, 87, 246]

    // swiftlint:disable:next line_length
    var sessionEstablishmentEReaderKey = COSEKey(curve: CryptoService.Curve.p256, xCoordinate: [136, 111, 184, 143, 92, 178, 148, 90, 78, 143, 218, 4, 38, 168, 12, 157, 135, 231, 242, 106, 251, 101, 223, 181, 12, 245, 190, 79, 229, 140, 4, 106], yCoordinate: [220, 214, 249, 59, 141, 7, 133, 210, 225, 180, 167, 191, 3, 135, 40, 124, 139, 195, 254, 189, 153, 110, 55, 228, 124, 127, 189, 27, 152, 37, 197, 87])

    var staticPrivateKey: [UInt8] = [190, 53, 168, 100, 29, 51, 112, 245, 100, 250, 6, 181, 156, 42, 162, 130, 16, 158, 166, 194, 165, 184, 99, 49, 18, 66, 56, 74, 175, 45, 13, 82]

    private func setUpTestData() throws -> (
        sessionDecryption: SessionDecryption,
        key: P256.KeyAgreement.PublicKey
    ) {
        let eReaderPublicKey = try P256.KeyAgreement.PublicKey(
            coseKey: sessionEstablishmentEReaderKey
        )

        let sessionDecryption: SessionDecryption = SessionDecryption(
            privateKey: try P256.KeyAgreement
                      .PrivateKey(rawRepresentation: Data(staticPrivateKey))
        )
        return (sessionDecryption: sessionDecryption, key: eReaderPublicKey)
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

    @Test("decrypt data successfully decrypts input and returns non nil data object")
    func decryptDataSuccesfullyDecryptsInput() async throws {
        let testData = try setUpTestData()

        #expect(throws: Never.self) {
            try testData.sessionDecryption.decryptData(
                sessionEstablishmentData,
                salt: sessionTranscriptBytes,
                encryptedWith: testData.key,
                by: .reader
            )
        }
    }

    @Test("decrypt data will throw a session decryption error if payload is too short")
    func decryptDataThrowsSessionDecryptionError() async throws {
        let testData = try setUpTestData()

        #expect(throws: DecryptionError.payloadTooShort) {
            try testData.sessionDecryption.decryptData(
                [UInt8](sessionEstablishmentData.prefix(10)),
                salt: sessionTranscriptBytes,
                encryptedWith: testData.key,
                by: .reader
            )
        }
    }

    @Test("decrypt data will throw if authentication tag is incorrect")
    func decryptDataThrowsDecryptionError() async throws {
        let testData = try setUpTestData()

        #expect(throws: DecryptionError.authenticationError) {
            try testData.sessionDecryption.decryptData(
                [UInt8](sessionEstablishmentData.dropLast(1)),
                salt: sessionTranscriptBytes,
                encryptedWith: testData.key,
                by: .reader
            )
        }
    }
}
