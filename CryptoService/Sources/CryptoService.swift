import CryptoKit
import Foundation
import SwiftCBOR


public struct CryptoService {
    var sessionDecryption: SessionDecryption
    var messageCounter: Int // Will likely need to move to HolderSession once it is implemented here

    public init(sessionDecryption: SessionDecryption, messageCounter: Int = 1) {
        self.sessionDecryption = sessionDecryption
        self.messageCounter = messageCounter
    }

    public mutating func decryptSessionEstablishmentMessage(from messageData: Data, with deviceEngagement: DeviceEngagement) throws {
        // Decode the SessionEstablishment message
        let sessionEstablishment = try SessionEstablishment(
            rawData: messageData
        )

        // Generate the PublicKey using the EReaderKey (COSEKey)
        let eReaderKey = try P256.KeyAgreement.PublicKey(
            coseKey: sessionEstablishment.eReaderKey
        )

        print("eReaderKey: \(eReaderKey)")

        // Generate the SessionTranscriptBytes
        let sessionTranscriptBytes = createSessionTranscriptBytes(with: deviceEngagement.encode(options: CBOROptions()), and: sessionEstablishment.eReaderKeyBytes)
        print("sessionEstablishment.data: \(sessionEstablishment.data)")
        // Decrypt the data
        do {
            let decryptedData = try sessionDecryption.decryptData(
                sessionEstablishment.data,
                salt: sessionTranscriptBytes,
                encryptedWith: eReaderKey,
                by: .reader
            )
            messageCounter = 2
            print("decryptedData: \(decryptedData.base64EncodedString())")
        } catch {
            messageCounter = 1
        }
    }

    private func createSessionTranscriptBytes(with deviceEngagementBytes: [UInt8], and eReaderKeyBytes: [UInt8]) -> [UInt8] {
        let sessionTranscript = SessionTranscript(
            deviceEngagementBytes: deviceEngagementBytes,
            eReaderKeyBytes: eReaderKeyBytes,
            handover: .qr
        )
        print("SessionTranscript constructed successfully: \(sessionTranscript)")

        return sessionTranscript
            .toCBOR(options: CBOROptions())
            .asDataItem(options: CBOROptions())
            .encode()
    }
}
