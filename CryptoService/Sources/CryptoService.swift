import CryptoKit
import UIKit
import Foundation
import SwiftCBOR

public protocol CryptoSessionProtocol: AnyObject {
    var cryptoContext: CryptoContext? { get set }
    var qrCode: UIImage? { get set }
}

public protocol CryptoServiceProtocol {
    func prepareEngagement(in session: CryptoSessionProtocol) throws
}

public struct CryptoService {
    var sessionDecryption: Decryption
    private(set) var messageCounter: Int // Will likely need to move to HolderSession once it is implemented here

    public init(sessionDecryption: Decryption, messageCounter: Int = 1) {
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
        print("messageCounter: \(messageCounter)")

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
            messageCounter += 1
            print("messageCounter: \(messageCounter)")
            print("decryptedData: \(decryptedData.base64EncodedString())")
        } catch {
            throw error
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

extension CryptoService: CryptoServiceProtocol {
    public func prepareEngagement(in session: CryptoSessionProtocol) throws {
        let serviceUUID = UUID()
        let deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceUUID
                    )
                )
            )]
        )
        let cryptoContext = CryptoContext(serviceUUID: serviceUUID, deviceEngagement: deviceEngagement)
        let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()
        
        session.cryptoContext = cryptoContext
        session.qrCode = qrCode
    }
}

// MARK: - CryptoContext
public struct CryptoContext {
    private(set) public var serviceUUID: UUID
    var deviceEngagement: DeviceEngagement
}
