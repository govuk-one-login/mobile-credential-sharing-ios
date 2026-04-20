import Foundation
@testable import SharingCryptoService
import Testing

struct SessionEncryptionTests {
    let messageCounter = 1
    let sut = SessionEncryption()
    
    @Test("encryptData returns successully encrypted valid data")
    func encryptDataIsSuccessful() throws {
        // Given
        let skDeviceKey: [UInt8] = [158, 43, 220, 8, 8, 165, 39, 27, 79, 224, 35, 130, 196, 249, 113, 113, 254, 244, 34, 190, 114, 72, 34, 80, 68, 155, 168, 237, 208, 175, 48, 41]
        let cipherText: [UInt8] = [120, 192]
        let authTag: [UInt8] = [244, 202, 54, 53, 63, 42, 99, 149, 164, 77, 243, 63, 94, 1, 152, 187]
        let expectedEncryptedData = Data(cipherText + authTag)
        
        // When
        let encryptedData = try sut.encryptData(Data([01, 02]), using: skDeviceKey, messageCounter: messageCounter, by: .device)
        
        // Then
        #expect(encryptedData == expectedEncryptedData)
    }
    
    @Test("encryptData correctly throws encryptionFailed")
    func encryptDataThrowsEncryptionFailed() throws {
        // Given
        let skDeviceKey: [UInt8] = [1]
        
        // When / Then
        #expect(throws: EncryptionError.encryptionFailed) {
            try sut.encryptData(Data([01, 02]), using: skDeviceKey, messageCounter: messageCounter, by: .device)
        }
    }
    
    @Test("encryptFailed error has correct description")
    func encryptionFailedErrorDescription() {
        // Given
        let error = EncryptionError.encryptionFailed

        // Then
        #expect(error.errorDescription == "AES-256-GCM encryption failed (status code 10)")
    }
}
