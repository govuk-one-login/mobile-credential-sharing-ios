import CryptoKit
import SwiftCBOR
import UIKit

// MARK: - CryptoServiceError
public enum CryptoServiceError: LocalizedError {
    case sessionCryptoContextNotFound
    case skDeviceKeyNotFound
    
    var errorDescription: String {
        switch self {
        case .sessionCryptoContextNotFound:
            "CryptoContext object not found on the Session"
        case .skDeviceKeyNotFound:
            "SKDevice key not found on the Session"
        }
    }
}

// MARK: - Protocols
public protocol CryptoSessionProtocol: AnyObject {
    var cryptoContext: CryptoContext? { get }
    var qrCode: UIImage? { get }
    var messageCounter: Int { get set }
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws
    func setSKDeviceKey(_ key: [UInt8]) throws
}

public protocol CryptoServiceProtocol {
    func prepareEngagement(in session: CryptoSessionProtocol) throws
    func processSessionEstablishment(incoming bytes: Data, in session: CryptoSessionProtocol) throws -> DeviceRequest
    func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: CryptoSessionProtocol) throws -> Data
}

// MARK: - CryptoService
public struct CryptoService {
    var sessionDecryption: Decryption
    var sessionEncryption: Encryption

    public init(sessionDecryption: Decryption, sessionEncryption: Encryption = SessionEncryption()) {
        self.sessionDecryption = sessionDecryption
        self.sessionEncryption = sessionEncryption
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
    
    public func processSessionEstablishment(
        incoming messageData: Data,
        in session: CryptoSessionProtocol
    ) throws -> DeviceRequest {
        let sessionEstablishment = try SessionEstablishment(
            rawData: messageData
        )

        let eReaderKey = try P256.KeyAgreement.PublicKey(
            coseKey: sessionEstablishment.eReaderKey
        )

        print("eReaderKey: \(eReaderKey)")
        print("messageCounter: \(session.messageCounter)")

        guard let deviceEngagement = session.cryptoContext?.deviceEngagement else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        let sessionTranscriptBytes = createSessionTranscriptBytes(with: deviceEngagement.encode(options: CBOROptions()), and: sessionEstablishment.eReaderKeyBytes)
        print("sessionEstablishment.data: \(sessionEstablishment.data)")

        let decryptedData = try sessionDecryption.decryptData(
            sessionEstablishment.data,
            salt: sessionTranscriptBytes,
            encryptedWith: eReaderKey,
            by: .reader
        )
        session.messageCounter += 1
        
        // Store the derived SKDevice key on the session for later encryption
        if let sessionDecryption = sessionDecryption as? SessionDecryption,
           let skDeviceKey = sessionDecryption.skDeviceKey {
            try session.setSKDeviceKey(skDeviceKey)
        }
        
        print("messageCounter: \(session.messageCounter)")
        print("decryptedData: \(decryptedData.base64EncodedString())")
            
        let deviceRequest = try DeviceRequest(data: decryptedData)
        print("DeviceRequest successfully mapped to model: \(deviceRequest)")
        
        return deviceRequest
    }
    
    public func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: CryptoSessionProtocol) throws -> Data {
        guard let skDeviceKey = session.cryptoContext?.skDeviceKey else {
            throw CryptoServiceError.skDeviceKeyNotFound
        }
        
        let plaintext = Data(deviceResponse.toCBOR().encode())
        let encryptedData = try sessionEncryption.encryptData(
            plaintext,
            using: skDeviceKey,
            messageCounter: &session.messageCounter,
            by: .device
        )
        return encryptedData
    }
}

// MARK: - CryptoContext
public struct CryptoContext {
    private(set) public var serviceUUID: UUID
    public var deviceEngagement: DeviceEngagement
    public var skDeviceKey: [UInt8]?
    
    public init(serviceUUID: UUID, deviceEngagement: DeviceEngagement, skDeviceKey: [UInt8]? = nil) {
        self.serviceUUID = serviceUUID
        self.deviceEngagement = deviceEngagement
        self.skDeviceKey = skDeviceKey
    }
}
