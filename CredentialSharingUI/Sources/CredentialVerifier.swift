import Foundation
import UIKit

/// Main entry point for the Verifier role.
/// The Consumer initialises this class to request and verify credentials.
@MainActor
public class CredentialVerifier {
    private let trustedCertificates: [SecCertificate]
    
    /// Initialises the Verifier module with trusted root certificates.
    /// - Parameter trustedCertificates: Root CAs used to validate the Issuer's signature on credentials
    public init(trustedCertificates: [SecCertificate]) {
        self.trustedCertificates = trustedCertificates
    }
    
    /// Requests a document from a Holder and returns the verified data.
    /// The SDK handles the complete lifecycle: camera scanning, BLE connection,
    /// request transmission, response decryption, and cryptographic validation.
    /// - Parameters:
    ///   - request: The credential request specifying document type and required attributes
    ///   - presentingViewController: The view controller to present the camera scanner from
    /// - Returns: Verified credential data
    /// - Throws: Errors if verification fails, user cancels, or connection issues occur
    public func requestDocument(
        _ request: VerifierCredentialRequest,
        presentingFrom presentingViewController: UIViewController
    ) async throws -> VerifiedCredentialData {
        // TODO: DCMAW-19082 Implementation to be added
        fatalError("Not yet implemented")
    }
}

/// Represents a request for specific credential attributes.
public struct VerifierCredentialRequest {
    public let documentType: String
    public let requestedElements: [String: Bool]  // attribute name -> intent to retain
    
    public init(documentType: String, requestedElements: [String: Bool]) {
        self.documentType = documentType
        self.requestedElements = requestedElements
    }
}

/// Represents verified credential data returned by the SDK.
public struct VerifiedCredentialData {
    private let data: [String: Any]
    
    public init(data: [String: Any]) {
        self.data = data
    }
    
    /// Retrieves a value for a specific attribute.
    /// - Parameter key: The attribute name
    /// - Returns: The value for the attribute, or nil if not present
    public func getValue(for key: String) -> Any? {
        return data[key]
    }
}
