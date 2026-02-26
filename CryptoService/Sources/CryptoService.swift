import CryptoKit
import SwiftCBOR
import UIKit

// MARK: - CryptoServiceError
enum CryptoServiceError: LocalizedError {
    case sessionCryptoContextNotFound
}

// MARK: - Protocols
public protocol CryptoSessionProtocol: AnyObject {
    var cryptoContext: CryptoContext? { get }
    var qrCode: UIImage? { get }
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws
}

public protocol CryptoServiceProtocol {
    func prepareEngagement(in session: CryptoSessionProtocol) throws
    mutating func processSessionEstablishment(incoming bytes: Data, in session: CryptoSessionProtocol) throws
}

// MARK: - CryptoService
public struct CryptoService {
    var sessionDecryption: Decryption
    private(set) var messageCounter: Int // Will likely need to move to HolderSession once it is implemented here

    public init(sessionDecryption: Decryption, messageCounter: Int = 1) {
        self.sessionDecryption = sessionDecryption
        self.messageCounter = messageCounter
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

// MARK: - CryptoServiceProtocol Implementation
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
        
        try session.setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
    }
    
    public mutating func processSessionEstablishment(incoming messageData: Data, in session: CryptoSessionProtocol) throws {
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
        guard let deviceEngagement = session.cryptoContext?.deviceEngagement else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
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
            
            // TODO: DCMAW-17055 Build DeviceRequest here
        } catch {
            throw error
        }
    }
}

// MARK: - CryptoContext
public struct CryptoContext {
    private(set) public var serviceUUID: UUID
    public var deviceEngagement: DeviceEngagement
    
    public init(serviceUUID: UUID, deviceEngagement: DeviceEngagement) {
        self.serviceUUID = serviceUUID
        self.deviceEngagement = deviceEngagement
    }
}
