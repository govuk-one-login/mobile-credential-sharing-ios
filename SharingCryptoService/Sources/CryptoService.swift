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
    var skReaderMessageCounter: Int { get set }
    var skDeviceMessageCounter: Int { get set }
    var sessionTranscript: SessionTranscript? { get }
    var docType: DocType? { get }
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws
    func setSKDeviceKey(_ key: [UInt8]) throws
    func setSessionTranscriptAndDocType(sessionTranscript: SessionTranscript, docType: DocType) throws
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
    
    private func createSessionTranscript(
        with deviceEngagementBytes: [UInt8],
        and eReaderKeyBytes: [UInt8]
    ) -> SessionTranscript {
        
        let sessionTranscript = SessionTranscript(
            deviceEngagementBytes: deviceEngagementBytes,
            eReaderKeyBytes: eReaderKeyBytes,
            handover: .qr
        )
        print("SessionTranscript constructed successfully: \(sessionTranscript)")

        return sessionTranscript
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
        print("messageCounter: \(session.skReaderMessageCounter)")

        guard let deviceEngagement = session.cryptoContext?.deviceEngagement else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }

        let sessionTranscript = createSessionTranscript(
            with: deviceEngagement.encode(options: CBOROptions()),
            and: sessionEstablishment.eReaderKeyBytes
        )
        print("sessionEstablishment.data: \(sessionEstablishment.data)")
        
        // Convert the sessionTranscipt into bytes to be used as the salt input for decryptData
        let sessionTranscriptBytes = sessionTranscript
            .toCBOR(options: CBOROptions())
            .asDataItem(options: CBOROptions())
            .encode()

        // Decrypt the data
        let decryptedData = try sessionDecryption.decryptData(
            sessionEstablishment.data,
            salt: sessionTranscriptBytes,
            messageCounter: session.skReaderMessageCounter,
            encryptedWith: eReaderKey,
            by: .reader
        )
        
        session.skReaderMessageCounter += 1
        
        // Store the derived SKDevice key on the session for later encryption
        if let skDeviceKey = sessionDecryption.skDeviceKey {
            try session.setSKDeviceKey(skDeviceKey)
        }
        
        print("messageCounter: \(session.skReaderMessageCounter)")
        print("decryptedData: \(decryptedData.base64EncodedString())")
            
        let deviceRequest = try DeviceRequest(data: decryptedData)
        print("DeviceRequest successfully mapped to model: \(deviceRequest)")
        
        // Store the docType of the requested document
        guard let docType = deviceRequest.docRequests.first?.itemsRequest.docType else {
            throw DeviceRequestError.itemsRequestWasIncorrectlyStructured
        }
        
        // Store the sessionTranscript and docType for later cryptograhic use
        try session.setSessionTranscriptAndDocType(
            sessionTranscript: sessionTranscript,
            docType: docType
        )
        
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
            messageCounter: session.skDeviceMessageCounter,
            by: .device
        )
        session.skDeviceMessageCounter += 1
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
