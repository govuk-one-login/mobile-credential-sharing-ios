import Foundation
import SharingCryptoService
import SwiftCBOR
import UIKit

class MockCryptoService: CryptoServiceProtocol {
    /// When true, this will cause the session to not set the engagement correctly, forcing a failure in the Orchestrator
    var forceFailureWithInvalidData: Bool = false
    var didCallProcessSessionEstablishment: Bool = false
    var incomingBytes: Data?
    var passedSession: CryptoHolderSessionProtocol?
    var proccessSessionEstablishmentShouldThrow: Bool = false
    var stubbedDeviceRequest: DeviceRequest?
    var stubbedEncryptedResponse: Data = Data()
    var encryptDeviceResponseError: CryptoServiceError?
    var passedDeviceResponse: DeviceResponse?
    
    var constructDeviceAuthenticationBytesShouldThrow: Bool = false
    var stubbedDeviceAuthenticationBytes: Data = Data()
    var didCallConstructDeviceAuthenticationBytes: Bool = false
    
    var didCallGenerateDeviceSigned: Bool = false
    var stubbedDeviceSigned: DeviceSigned?
    
    var processQRCodeError: (any Error)?
    
    var stubbedServiceUUID: UUID = UUID()
    
    var generateSessionEstablishmentError: (any Error)?

    var didCallgenerateSessionEstablishment: Bool = false
    var passedDeviceRequest: DeviceRequest?
    
    var didCallProcessResponse: Bool = false
    var incomingProcessResponseMessageData: Data?
    
    func prepareEngagement(in session: any CryptoHolderSessionProtocol) throws {
        if !forceFailureWithInvalidData {
            let mockCryptoContext = CryptoContext(
                serviceUUID: UUID(),
                deviceEngagement: try DeviceEngagement(
                    // swiftlint:disable:next line_length
                    from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
                )
            )
            try session.setEngagement(cryptoContext: mockCryptoContext, qrCode: UIImage())
        }
    }
    
    func processSessionEstablishment(incoming bytes: Data, in session: any CryptoHolderSessionProtocol) throws -> DeviceRequest {
        didCallProcessSessionEstablishment = true
        
        if proccessSessionEstablishmentShouldThrow {
            throw SessionEstablishmentError.cborMapMissing
        }
        incomingBytes = bytes
        passedSession = session
        
        if let stubbedDeviceRequest {
            return stubbedDeviceRequest
        }
        return try DeviceRequest(data: bytes)
    }
    
    func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: any CryptoHolderSessionProtocol) throws -> Data {
        if let encryptDeviceResponseError {
            throw encryptDeviceResponseError
        }
        self.passedDeviceResponse = deviceResponse
        return stubbedEncryptedResponse
    }
    
    func buildTerminationMessage(encryptedPayload: Data?, in session: any CryptoHolderSessionProtocol) -> Data {
        let sessionData = SessionData(data: encryptedPayload, status: .sessionTermination)
        return Data(sessionData.encode(options: CBOROptions()))
    }
    
    func constructDeviceAuthenticationBytes(in session: any CryptoHolderSessionProtocol) throws {
        didCallConstructDeviceAuthenticationBytes = true
        
        if constructDeviceAuthenticationBytesShouldThrow {
            throw CryptoServiceError.deviceAuthenticationElementsNotFound
        }
        
        try session.setDeviceAuthenticationBytes(stubbedDeviceAuthenticationBytes)
    }
    
    func generateDeviceSigned(in session: any CryptoHolderSessionProtocol) throws {
        didCallGenerateDeviceSigned = true
        
        guard let signatureBytes = session.signatureBytes else {
            throw CryptoServiceError.deviceAuthenticationElementsNotFound
        }
        
        let deviceSigned: DeviceSigned
        if let stubbedDeviceSigned {
            deviceSigned = stubbedDeviceSigned
        } else {
            deviceSigned = DeviceSigned(
                nameSpaces: CBOR.map([:]).encode(),
                deviceAuth: DeviceAuth(deviceSignature: .array([
                    .byteString(CBOR.map([.unsignedInt(1): .negativeInt(6)]).encode()),
                    .map([:]),
                    .null,
                    .byteString([UInt8](signatureBytes))
                ]))
            )
        }
        
        try session.setDeviceSigned(deviceSigned: deviceSigned)
    }
    
    func processQRCode(_ qrCode: String, in session: any CryptoVerifierSessionProtocol) throws {
        if let processQRCodeError {
            throw processQRCodeError
        }
        let cryptoContext = CryptoContext(
            serviceUUID: stubbedServiceUUID,
            deviceEngagement: try DeviceEngagement(
                from: "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
            )
        )
        try session.setEngagement(cryptoContext: cryptoContext)
    }

    func generateSessionEstablishment(with deviceRequest: DeviceRequest, in session: any CryptoVerifierSessionProtocol) throws {
        didCallgenerateSessionEstablishment = true
        passedDeviceRequest = deviceRequest
        if let generateSessionEstablishmentError {
            throw generateSessionEstablishmentError
        }
    }
    
    func processResponse(_ messageData: Data, in session: any CryptoVerifierSessionProtocol) throws {
        didCallProcessResponse = true
        incomingProcessResponseMessageData = messageData
    }
}
