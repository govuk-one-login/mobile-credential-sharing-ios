import CryptoKit
import SwiftCBOR
import UIKit

// MARK: - CryptoServiceError
// swiftlint:disable file_length
public enum CryptoServiceError: LocalizedError, Equatable {
    case sessionCryptoContextNotFound
    case skDeviceKeyNotFound
    case skReaderKeyNotFound
    case deviceAuthenticationElementsNotFound
    
    case nonMdocQRScanned

    case eDeviceKeyIncompatibleCurve(String)
    case eDeviceKeyMalformed(CryptoKitError)
    
    case eReaderKeyBytesMalformed
    
    public var errorDescription: String? {
        switch self {
        case .sessionCryptoContextNotFound:
            "CryptoContext object not found on the Session"
        case .skDeviceKeyNotFound:
            "SKDevice key not found on the Session"
        case .skReaderKeyNotFound:
            "SKReader key not found on the Session"
        case .deviceAuthenticationElementsNotFound:
            "DeviceAuthentication elements not found on the session"
        case .nonMdocQRScanned:
            "Scanned QR Code does not contain 'mdoc:' prefix"
        case .eDeviceKeyIncompatibleCurve(let curve):
            "Error computing shared secret due to EDeviceKey.Pub with incompatible curve: \(curve)."
        case .eDeviceKeyMalformed(let error):
            "Error computing shared secret due to malformed EDeviceKey.Pub: \(error)."
        case .eReaderKeyBytesMalformed:
            "EReaderKeyBytes has invalid CBOR structure."
        }
    }
}

// MARK: - Protocols
public protocol CryptoHolderSessionProtocol: AnyObject {
    var cryptoContext: CryptoContext? { get }
    var qrCode: UIImage? { get }
    var skReaderMessageCounter: Int { get set }
    var skDeviceMessageCounter: Int { get set }
    var sessionTranscript: SessionTranscript? { get }
    var docType: DocType? { get }
    var deviceAuthenticationBytes: Data? { get }
    var signatureBytes: Data? { get }
    var deviceSigned: DeviceSigned? { get }
    
    func setEngagement(cryptoContext: CryptoContext, qrCode: UIImage) throws
    func setSKDeviceKey(_ key: [UInt8]) throws
    func setSessionTranscriptAndDocType(sessionTranscript: SessionTranscript, docType: DocType) throws
    func setDeviceAuthenticationBytes(_ bytes: Data) throws
    func setSignatureBytes(_ bytes: Data) throws
    func setDeviceSigned(deviceSigned: DeviceSigned) throws
}

public protocol CryptoVerifierSessionProtocol: AnyObject {
    var cryptoContext: CryptoContext? { get }
    var skReaderMessageCounter: Int { get set }
    
    func setEngagement(cryptoContext: CryptoContext) throws
    func setSessionKeys(skReaderKey: [UInt8], skDeviceKey: [UInt8]) throws
    func setSessionEstablishment(_ data: Data) throws
}

public protocol CryptoServiceProtocol {
    // MARK: - Holder functions
    func prepareEngagement(in session: CryptoHolderSessionProtocol) throws
    func processSessionEstablishment(incoming bytes: Data, in session: CryptoHolderSessionProtocol) throws -> DeviceRequest
    func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: CryptoHolderSessionProtocol) throws -> Data
    func constructDeviceAuthenticationBytes(in session: CryptoHolderSessionProtocol) throws
    func generateDeviceSigned(in session: CryptoHolderSessionProtocol) throws
    
    // MARK: - Verifier functions
    func processQRCode(_ qrCode: String, in session: CryptoVerifierSessionProtocol) throws
    func generateSessionEstablishment(with deviceRequest: DeviceRequest, in session: CryptoVerifierSessionProtocol) throws
    func processResponse(_ messageData: Data, in session: CryptoVerifierSessionProtocol) throws
}

// MARK: - CryptoService
public struct CryptoService {
    var sessionDecryption: Decryption
    var sessionEncryption: Encryption

    public init(
        sessionDecryption: Decryption,
        sessionEncryption: Encryption = SessionEncryption()
    ) {
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
    public func prepareEngagement(in session: CryptoHolderSessionProtocol) throws {
        let privateKey = P256.KeyAgreement.PrivateKey()
        let serviceUUID = UUID()
        let deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: privateKey.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceUUID
                    )
                )
            )]
        )
        let cryptoContext = CryptoContext(serviceUUID: serviceUUID, deviceEngagement: deviceEngagement, privateKey: privateKey)
        let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()
        
        try session.setEngagement(cryptoContext: cryptoContext, qrCode: qrCode)
    }
    
    public func processSessionEstablishment(
        incoming messageData: Data,
        in session: CryptoHolderSessionProtocol
    ) throws -> DeviceRequest {
        let sessionEstablishment = try SessionEstablishment(
            rawData: messageData
        )

        let eReaderKey = try P256.KeyAgreement.PublicKey(
            coseKey: sessionEstablishment.eReaderKey
        )

        print("eReaderKey: \(eReaderKey)")
        print("messageCounter: \(session.skReaderMessageCounter)")

        guard let cryptoContext = session.cryptoContext,
              let privateKey = cryptoContext.privateKey else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }

        let sessionTranscript = createSessionTranscript(
            with: cryptoContext.deviceEngagement.encode(options: CBOROptions()),
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
            using: privateKey,
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
        
        // Extract the docType of the first document item from the device request
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
    
    public func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: CryptoHolderSessionProtocol) throws -> Data {
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
    
    public func generateDeviceSigned(
        in session: CryptoHolderSessionProtocol
    ) throws {
        guard let signatureBytes = session.signatureBytes else {
            throw CryptoServiceError.deviceAuthenticationElementsNotFound
        }
        
        let protectedHeaderBytes = COSEAlgorithm.es256.protectedHeaderCBOR.encode()
        
        // Construct the untagged COSE_Sign1 array
        let coseSign1: CBOR = .array([
            .byteString(protectedHeaderBytes),
            .map([:]),
            .null,
            .byteString([UInt8](signatureBytes))
        ])
        
        // Construct DeviceAuth
        let deviceAuth = DeviceAuth(deviceSignature: coseSign1)
        
        // Construct DeviceNameSpacesBytes as Tag 24 empty map
        let deviceNameSpaces: CBOR = .map([:])
        let deviceNameSpacesBytes = deviceNameSpaces.encode()
        
        // Construct DeviceSigned
        let deviceSigned = DeviceSigned(
            nameSpaces: deviceNameSpacesBytes,
            deviceAuth: deviceAuth
        )
        
        try session.setDeviceSigned(deviceSigned: deviceSigned)
    }
    
    public func constructDeviceAuthenticationBytes(
        in session: CryptoHolderSessionProtocol
    ) throws {
        // The SessionTranscript element is defined in 12.6.1.
        // The DocType contains the same data as the Document element in the mdoc response (10.3.3).
        guard let sessionTranscript = session.sessionTranscript,
              let docType = session.docType else {
            print("error constructing DeviceAuthenticationBytes")
            throw CryptoServiceError.deviceAuthenticationElementsNotFound
        }
            
        // DeviceNameSpaces is an empty map {} (MVP) but will contain the same data as the DeviceResponse (10.3.3).
        let deviceNameSpaces: CBOR = .map([:])
        let deviceNameSpacesBytes = deviceNameSpaces.asDataItem(
            options: CBOROptions()
        )
            
        // Assemble the DeviceAuthentication array, encode and wrap it as tagged CBOR bytes
        let deviceAuthentication: CBOR = .array([
            .utf8String("DeviceAuthentication"),
            sessionTranscript.toCBOR(options: CBOROptions()),
            .utf8String(docType.rawValue),
            deviceNameSpacesBytes
        ])
            
        let deviceAuthenticationBytes = deviceAuthentication
            .asDataItem(options: CBOROptions())
            .encode()
            
        print(
            "DeviceAuthenticationBytes constructed successfully: \(deviceAuthenticationBytes)"
        )
            
        try session.setDeviceAuthenticationBytes(Data(deviceAuthenticationBytes))
    }
}

// MARK: - Verifier functionality
extension CryptoService {
    public func processQRCode(
        _ qrCode: String,
        in session: CryptoVerifierSessionProtocol
    ) throws {
        guard isMdocString(qrCode) else {
            throw CryptoServiceError.nonMdocQRScanned
        }
        
        let mdocString = qrCode.replacingOccurrences(of: "mdoc:", with: "")
        let deviceEngagement = try DeviceEngagement(from: mdocString)
        
        let privateKey = P256.KeyAgreement.PrivateKey()
        let eReaderKeyBytes = generateEReaderKeyBytes(from: privateKey.publicKey)
        #if DEBUG
        print("eReaderKeyBytes: \(Data(eReaderKeyBytes).base64EncodedString())")
        #endif
        
        let cryptoContext = CryptoContext(
            serviceUUID: deviceEngagement.peripheralServiceUUID,
            deviceEngagement: deviceEngagement,
            privateKey: privateKey,
            eReaderKeyBytes: eReaderKeyBytes
        )
        
        try session.setEngagement(cryptoContext: cryptoContext)
    }
    
    private func isMdocString(_ value: String) -> Bool {
        return value.lowercased().hasPrefix("mdoc:")
    }
    
    private func generateEReaderKeyBytes(from publicKey: P256.KeyAgreement.PublicKey) -> [UInt8] {
        let eReaderKey = EReaderKey(publicKey: publicKey)
        let eReaderKeyCBOR = eReaderKey.toCBOR(options: CBOROptions())

        let encodedKey = eReaderKeyCBOR.encode()
        let taggedCBORByteString = CBOR.tagged(.encodedCBORDataItem, .byteString(encodedKey)).encode()
        #if DEBUG
        print("base64 eReaderKeyCBOR: \(Data(encodedKey).base64EncodedString())")
        print("taggedCBORByteString: \(Data(taggedCBORByteString).base64EncodedString())")
        #endif
        return taggedCBORByteString
    }

    public func generateSessionEstablishment(
        with deviceRequest: DeviceRequest,
        in session: CryptoVerifierSessionProtocol
    ) throws {
        try constructSessionTranscript(in: session)
        let sharedSecret = try computeSharedSecret(in: session)

        guard let cryptoContext = session.cryptoContext,
              let sessionTranscriptBytes = cryptoContext.sessionTranscriptBytes else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }

        let skReader = sessionDecryption.deriveSKReader(
            sharedSecret: sharedSecret,
            sessionTranscriptBytes: sessionTranscriptBytes
        )
        let skDevice = sessionDecryption.deriveSKDevice(
            sharedSecret: sharedSecret,
            sessionTranscriptBytes: sessionTranscriptBytes
        )

        try session.setSessionKeys(skReaderKey: skReader, skDeviceKey: skDevice)
        
        try assembleAndEncryptRequest(deviceRequest, in: session)
    }
    
    func constructSessionTranscript(in session: CryptoVerifierSessionProtocol) throws {
        guard var cryptoContext = session.cryptoContext,
              let eReaderKeyBytes = cryptoContext.eReaderKeyBytes
        else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        let deviceEngagementBytes = cryptoContext.deviceEngagement.encode(options: CBOROptions())
        
        // Create the SessionTranscript
        let sessionTranscript = createSessionTranscript(
            with: deviceEngagementBytes,
            and: eReaderKeyBytes
        )
        
        print("SessionTranscript CBOR: \(sessionTranscript.toCBOR(options: CBOROptions()))")
        
        // Convert the SessionTranscript into CBOR.Tagged byte array
        let sessionTranscriptBytes = sessionTranscript
            .toCBOR(options: CBOROptions())
            .asDataItem(options: CBOROptions())
            .encode()
        
        print("SessionTranscriptBytes constructed successfully: \(Data(sessionTranscriptBytes).base64EncodedString())")
        
        // Set sessionTranscriptBytes on cryptoContext & update session
        cryptoContext.sessionTranscriptBytes = sessionTranscriptBytes
        try session.setEngagement(cryptoContext: cryptoContext)
    }

    private func computeSharedSecret(in session: CryptoVerifierSessionProtocol) throws -> SharedSecret {
        guard let cryptoContext = session.cryptoContext,
              let privateKey = cryptoContext.privateKey else {
            throw CryptoServiceError.sessionCryptoContextNotFound
        }
        
        let eDeviceKey = cryptoContext.deviceEngagement.security.eDeviceKey
        let eDevicePublicKey: P256.KeyAgreement.PublicKey
        
        do {
            eDevicePublicKey = try P256.KeyAgreement.PublicKey(coseKey: eDeviceKey)
        } catch COSEKeyError.unsupportedCurve(let curve) {
            let error = CryptoServiceError.eDeviceKeyIncompatibleCurve("\(curve)")
            print(error.localizedDescription)
            throw error
        } catch COSEKeyError.malformedKeyData(let cryptoKitError) {
            let error = CryptoServiceError.eDeviceKeyMalformed(cryptoKitError)
            print(error.localizedDescription)
            throw error
        }
        
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: eDevicePublicKey)
        print("Shared secret (ZAB) computed successfully")
        return sharedSecret
    }
    
    private func assembleAndEncryptRequest(
        _ deviceRequest: DeviceRequest,
        in session: CryptoVerifierSessionProtocol
    ) throws {
        let encryptedData = try encryptDeviceRequest(
            deviceRequest,
            in: session
        )
        
        guard let eReaderKeyBytes = session.cryptoContext?.eReaderKeyBytes else {
            return
        }
        
        // Extract the inner COSE_Key bytes from the Tag(24, bstr(...)) encoded eReaderKeyBytes
        guard case .tagged(.encodedCBORDataItem, .byteString(let innerKeyBytes)) = try CBOR.decode(eReaderKeyBytes) else {
            throw CryptoServiceError.eReaderKeyBytesMalformed
        }
        
        // Construct SessionEstablishment and encode to CBOR bytes
        let sessionEstablishment = try SessionEstablishment(
            eReaderKeyBytes: innerKeyBytes,
            data: [UInt8](encryptedData)
        )
        let sessionEstablishmentBytes = Data(sessionEstablishment.toCBOR().encode())
        print("SessionEstablishment message constructed")
        
        try session.setSessionEstablishment(sessionEstablishmentBytes)
    }
    
    public func encryptDeviceRequest(
        _ deviceRequest: DeviceRequest,
        in session: any CryptoVerifierSessionProtocol
    ) throws -> Data {
        guard let skReaderKey = session.cryptoContext?.skReaderKey else {
            throw CryptoServiceError.skReaderKeyNotFound
        }
        print("Message counter: \(session.skReaderMessageCounter)")
        let plaintext = Data(deviceRequest.toCBOR().encode())
        let encryptedData = try sessionEncryption.encryptData(
            plaintext,
            using: skReaderKey,
            messageCounter: session.skReaderMessageCounter,
            by: .reader
        )
        
        print("DeviceRequest encrypted successfully")
        
        session.skReaderMessageCounter += 1
        print("Message counter: \(session.skReaderMessageCounter)")
        
        return encryptedData
    }

    public func processResponse(
        _ messageData: Data,
        in session: CryptoVerifierSessionProtocol
    ) throws {
        print("Decoder received complete SessionData message.")
        // TODO: DCMAW-19309 Decode messageData into SessionData object
    }
}

// MARK: - CryptoContext
public struct CryptoContext {
    private(set) public var serviceUUID: UUID?
    public var deviceEngagement: DeviceEngagement
    public var privateKey: P256.KeyAgreement.PrivateKey?
    public var skReaderKey: [UInt8]?
    public var skDeviceKey: [UInt8]?
    public var eReaderKeyBytes: [UInt8]?
    public var sessionTranscriptBytes: [UInt8]?
    
    public init(
        serviceUUID: UUID? = nil,
        deviceEngagement: DeviceEngagement,
        privateKey: P256.KeyAgreement.PrivateKey? = nil,
        skReaderKey: [UInt8]? = nil,
        skDeviceKey: [UInt8]? = nil,
        eReaderKeyBytes: [UInt8]? = nil,
        sessionTranscriptBytes: [UInt8]? = nil
    ) {
        self.serviceUUID = serviceUUID
        self.deviceEngagement = deviceEngagement
        self.privateKey = privateKey
        self.skReaderKey = skReaderKey
        self.skDeviceKey = skDeviceKey
        self.eReaderKeyBytes = eReaderKeyBytes
        self.sessionTranscriptBytes = sessionTranscriptBytes
    }
}
