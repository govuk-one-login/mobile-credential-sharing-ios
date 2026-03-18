## Sample Implementations: Consumer Responsibilities

#### Holder Role: Secure Vault

This implementation demonstrates the boundary between the SDK and the Consumer for the Holder role. The Consumer acts as a secure vault: retrieving raw credential data and proxying signing requests to the Secure Enclave. The SDK handles CBOR parsing, filtering, transport and encryption.

```swift
import CredentialSharingUI
import CryptoKit

class SecureVaultCredentialProvider: CredentialProvider {
    
    private let secureStorage = MySecureStorage() 
    
    /// 1. Query Credentials: Return raw CBOR credential data
    /// Initially this will always return an array of exactly one element
    func getCredentials(
        for request: CredentialRequest
    ) async throws -> [Credential] {
        // Retrieve and decrypt the credential from secure storage
        let rawCredential = try await secureStorage.fetchCredential(
            matching: request.documentTypes
        )
        
        return [Credential(
            id: rawCredential.id,
            rawCredential: rawCredential.cborData
        )]
    }
    
    /// 2. Device Authentication: Sign the DeviceAuthentication payload
    func sign(
        payload: Data, 
        documentID: String
    ) async throws -> Data {
        let privateKey = try await secureStorage.getSecureEnclaveKey(for: documentID)
        let signature = try privateKey.signature(for: payload)
        return signature.rawRepresentation
    }
}
```

#### Verifier Role: Trust Anchor & Consumption

This implementation demonstrates how the Consumer acts as a relying party. It provides trusted Root CAs to the SDK, defines what data is required, and processes the decrypted, verified response, while the SDK handles the engagement and transport lifecycle.

```swift
import CredentialSharing
import UIKit
class AgeVerificationViewController: UIViewController {
    // 1. Initialise Verifier with Trusted Root Certificates
    private lazy var verifier: CredentialVerifier = {
        let govRootCA = loadGovernmentRootCertificate()
        return CredentialVerifier(trustedCertificates: [govRootCA])
    }()
    func startAgeVerification() {
        Task {
            // 2. Define the Request
            let request = CredentialRequest(
                documentType: "org.iso.18013.5.1.mDL",
                requestedElements: ["age_over_18"]
            )
            do {
                // 3. Start Verification Lifecycle
                // The SDK takes over, shows the camera, connects via BLE, and cryptographically validates the MSO.
                let verifiedData = try await verifier.requestDocument(
                    request, 
                    presentingFrom: self
                )
                // 4. Process Verified Data
                if let isOver18 = verifiedData.getValue(for: "age_over_18") as? Bool, isOver18 {
                    print("Success: Customer is over 18.")
                } else {
                    print("Failure: Customer is under 18.")
                }
            } catch {
                print("Verification interrupted or invalid: \(error.localizedDescription)")
            }
        }
    }
    private func loadGovernmentRootCertificate() -> SecCertificate {
        // Load the public trusted root CA from app bundle
        fatalError("Unimplemented")
    }
}
```
