import BluetoothTransport
import CoreBluetooth
import CryptoKit
import CryptoService
internal import SwiftCBOR
import UIKit

@MainActor
public protocol CredentialPresenting {
    func presentCredential(_ data: Data, over viewController: UIViewController)
}

extension CredentialPresenter: CredentialPresenting {}

@MainActor
public class CredentialPresenter {
    public var peripheralSession: PeripheralSession?
    public var deviceEngagement: DeviceEngagement?
    var sessionDecryption: SessionDecryption?
    fileprivate var cryptoService: CryptoService?
    var qrCodeViewController: QRCodeViewController?
    var baseViewController: UIViewController? {
        didSet {
            guard baseViewController?.navigationController != nil else {
                fatalError(
                    "Error: baseViewController is not embedded in a UINavigationController."
                )
            }
            navigationController = baseViewController?.navigationController
        }
    }
    var navigationController: UINavigationController?

    public init() {
        // Empty init required to declare class as public facing
    }
    
    private func createPeripheralSession(with credential: Data) -> PeripheralSession {
        let serviceId = UUID()
        
        let peripheralSession = PeripheralSession(serviceUUID: serviceId)
        sessionDecryption = SessionDecryption()
        guard let sessionDecryption else {
            fatalError("SessionDecryption was not initialized correctly.")
        }
        cryptoService = CryptoService(sessionDecryption: sessionDecryption)
        self.deviceEngagement = DeviceEngagement(
            security: Security(
                cipherSuiteIdentifier: CipherSuite.iso18013,
                eDeviceKey: EDeviceKey(publicKey: sessionDecryption.publicKey)
            ),
            deviceRetrievalMethods: [.bluetooth(
                .peripheralOnly(
                    PeripheralMode(
                        uuid: serviceId
                    )
                )
            )]
        )
        print(
            "the base64 encoded CBOR is: ",
            Data(deviceEngagement.toCBOR().encode()).base64EncodedString()
        )

        print("The public key is: ", sessionDecryption.publicKey)
        print("The private key is: ", sessionDecryption.privateKey)
        
        return peripheralSession
    }

    @MainActor
    public func presentCredential(
        _ credential: Data,  // raw CBOR credential
        over viewController: UIViewController
    ) {
        do {
            peripheralSession = createPeripheralSession(with: credential)
            baseViewController = viewController
            let qrCode: UIImage = try QRGenerator(data: Data(deviceEngagement.toCBOR().encode())).generateQRCode()

            peripheralSession?.delegate = self
            self.qrCodeViewController = QRCodeViewController(qrCode: qrCode)
            self.qrCodeViewController?.delegate = self
        } catch {
            print(
               error.localizedDescription
            )
        }
        
        guard let navigationController,
              self.qrCodeViewController != nil
        else {
            fatalError(
                "Error: baseViewController is not embedded in a UINavigationController."
            )
        }
        navigationController
            .present(self.qrCodeViewController!, animated: true)
    }
}

extension CredentialPresenter: @MainActor PeripheralSessionDelegate {
    @MainActor
    public func peripheralSessionDidUpdateState(
        withError error: PeripheralError?
    ) {
        switch error {
        case .permissionsNotGranted:
            navigateToErrorView(titleText: "Permission permanently denied")
        case .notPoweredOn:
            qrCodeViewController?.showSettingsButton()
        case .connectionTerminated:
            navigateToErrorView(titleText: error?.errorDescription ?? "")
        case .failedToNotifyEnd:
            navigateToErrorView(titleText: "BLE_ERROR")
        case nil:
            qrCodeViewController?.showQRCode()
        default:
            break
        }
    }
    
    public func peripheralSessionDidReceiveMessageData(_ messageData: Data) {
        do {
            guard let cryptoService,
                  let deviceEngagement else {
                navigateToErrorView(titleText: "cryptoService or deviceEngagement cannot be nil")
                return
            }
            try cryptoService.decryptSessionEstablishmentMessage(from: messageData, with: deviceEngagement)
        } catch let error as SessionEstablishmentError {
            navigateToErrorView(titleText: error.errorDescription)
        } catch COSEKeyError.unsupportedCurve(let curve) {
            navigateToErrorView(titleText: DecryptionError.computeSharedSecretCurve("\(curve) (\(curve.rawValue))")
                .errorDescription)
        } catch COSEKeyError.malformedKeyData(let error) {
            navigateToErrorView(titleText: DecryptionError
                .computeSharedSecretMalformedKey(error).errorDescription)
        } catch {
            navigateToErrorView(titleText: "Unknown Error")
        }
    }

    public func peripheralSessionDidReceiveMessageEndRequest() {
        qrCodeViewController?.dismiss(animated: true)
        navigateToErrorView(titleText: "Session ended by reader")
    }
}

extension CredentialPresenter: @MainActor QRCodeViewControllerDelegate {
    public func didTapCancel() {
        self.peripheralSession?.endSession()
    }

    public func didTapNavigateToSettings() {
        // Creates an unused CBPeripheralManager, which forces the system pop-up to navigate user to settings
        _ = CBPeripheralManager(
            delegate: nil,
            queue: nil,
            options: [
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    private func navigateToErrorView(titleText: String) {
        qrCodeViewController?.dismiss(animated: false)
        let errorViewController = ErrorViewController(titleText: titleText)
        navigationController?.pushViewController(errorViewController, animated: true)
    }
}

private struct CryptoService {
    var sessionDecryption: SessionDecryption
    
    func decryptSessionEstablishmentMessage(from messageData: Data, with deviceEngagement: DeviceEngagement) throws {
        // Decode the SessionEstablishment message
        let sessionEstablishment = try SessionEstablishment(
            rawData: messageData
        )
        print(sessionEstablishment)
        
        // Generate the PyblicKey using the EReaderKey (COSEKey)
        let eReaderKey = try P256.KeyAgreement.PublicKey(
            coseKey: sessionEstablishment.eReaderKey
        )
        
        // Generate the SessionTranscriptBytes
        let sessionTranscriptBytes = createSessionTranscriptBytes(with: deviceEngagement.encode(options: CBOROptions()), and: sessionEstablishment.eReaderKeyBytes)
        print("Session Transcript Bytes constructed successfully: \(sessionTranscriptBytes)")
        
        // Decrypt the data
        _ = try sessionDecryption.decryptData(
            messageData.encode(),
            salt: sessionTranscriptBytes,
            encryptedWith: eReaderKey,
            by: .reader
        )
        print("session establisment data: \(sessionEstablishment.data)")

        // TODO: Keep if SKReaderKey will be in CBOR or not (Richard to confirm)
        /*
        guard let cborData = try CBOR.decode(sessionEstablishment.data) else {
            print("oops")
            return
        }
        
        print("cborData: \(cborData)")
        
        guard case .byteString(let encryptedData) = cborData else {
            print("can't convert cbor to bytestring")
            return
        }
        */
        var messageCounter = 1
        let iv = constructIV(
            messageCounter: messageCounter
        )

        // Increment message Counter after successful decryption
        messageCounter += 1

        print("IV: \(iv)")

        let temp = try AES.GCM.Nonce(data: iv)
        print("temp: \(temp)")

        let cipherText = sessionEstablishment.data.dropLast(16) // Assuming the last 16 bytes are the tag
        let authenticationTag = sessionEstablishment.data.suffix(16)

        // TODO: Remove these 3 once we get Richard's SKReaderKey and can properly construct the SymmetricKey for decryption
        let skreader = Data("58d277d8719e62a1561d248f403f477e9e6c37bf5d5fc5126f8f4c727c22dfc9".utf8)
        let skreaderUInt8 = [UInt8](skreader)
        print("skreaderUInt8 count: \(skreaderUInt8.count)")

        let skreader2 = Data(base64Encoded: "58d277d8719e62a1561d248f403f477e9e6c37bf5d5fc5126f8f4c727c22dfc9")
        let skreader2UInt8 = [UInt8](skreader2 ?? Data())
        print("skreader2UInt8 count: \(skreader2UInt8.count)")

        let skreader3 = Data(hex: "58d277d8719e62a1561d248f403f477e9e6c37bf5d5fc5126f8f4c727c22dfc9")
        print("skreader3 count: \(skreader3?.count ?? 0)")



        let symmetricKey = SymmetricKey(data: skreader3 ?? Data())

        let sealedBox = try AES.GCM.SealedBox(
            nonce: temp,
            ciphertext: cipherText,
            tag: authenticationTag
        )

        print("sealedBox: \(sealedBox)")
        var decryptedData: Data = Data()
        do {
            decryptedData = try AES.GCM.open(
                sealedBox,
                using: symmetricKey
            )
        } catch {
            print("Decryption failed: \(error)")
        }

        print("decryptedData: \(decryptedData)")
        let decryptedString = String(data: decryptedData, encoding: .utf8)
        //print("decryptedString: \(decryptedString)")
        // TODO: 1.) Get SKReaderKey from Richard's ticket, 2.) Testing once functional, 3.) Authentication Tag (last 12 bytes) validation, 4.) Cleanup
    }

    private func constructIV(messageCounter: Int) -> Data {
        let identifier: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let convertedMessageCounter: Int32 = Int32(messageCounter)
        let messageCounterArray = withUnsafeBytes(of: convertedMessageCounter.bigEndian, Array.init)
        print(messageCounterArray)
        print("identifier: \(identifier)")
        let iv = identifier + messageCounterArray
        return Data(iv)
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
// TODO: Remove this temp 32 byte init
extension Data {
    init?(hex: String) {
        let hex = hex.count % 2 == 0 ? hex : "0" + hex
        var data = Data(capacity: hex.count / 2)

        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex,
                  let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
