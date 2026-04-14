import SharingCryptoService
import UIKit

class MockCryptoService: CryptoServiceProtocol {
    /// When true, this will cause the session to not set the engagement correctly, forcing a failure in the Orchestrator
    var forceFailureWithInvalidData: Bool = false
    var didCallProcessSessionEstablishment: Bool = false
    var incomingBytes: Data?
    var passedSession: CryptoSessionProtocol?
    var stubbedDeviceRequest: DeviceRequest?
    var stubbedEncryptedResponse: Data = Data()
    var encryptDeviceResponseError: Error?
    
    func prepareEngagement(in session: any CryptoSessionProtocol) throws {
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
    
    func processSessionEstablishment(incoming bytes: Data, in session: any CryptoSessionProtocol) throws -> DeviceRequest {
        didCallProcessSessionEstablishment = true
        incomingBytes = bytes
        passedSession = session
        
        if let stubbedDeviceRequest {
            return stubbedDeviceRequest
        }
        return try DeviceRequest(data: bytes)
    }
    
    func encryptDeviceResponse(_ deviceResponse: DeviceResponse, in session: any CryptoSessionProtocol) throws -> Data {
        if let encryptDeviceResponseError {
            throw encryptDeviceResponseError
        }
        return stubbedEncryptedResponse
    }
}
