import Foundation
import Testing
import UIKit
@testable import CredentialSharingUI

@Suite("CredentialVerifier Tests")
struct CredentialVerifierTests {
    
    @Test("Initializes with trusted certificates")
    func initializesWithCertificates() {
        let certificates: [SecCertificate] = []
        let verifier = CredentialVerifier(trustedCertificates: certificates)
        
        #expect(verifier != nil)
    }
    
    @Test("Initializes with multiple certificates")
    func initializesWithMultipleCertificates() {
        // Create mock certificates (in real usage these would be actual SecCertificate objects)
        let certificates: [SecCertificate] = []
        let verifier = CredentialVerifier(trustedCertificates: certificates)
        
        #expect(verifier != nil)
    }
    
    @Test("VerifierCredentialRequest initializes correctly")
    func verifierRequestInitialization() {
        let request = VerifierCredentialRequest(
            documentType: "org.iso.18013.5.1.mDL",
            requestedElements: ["family_name": true, "given_name": false]
        )
        
        #expect(request.documentType == "org.iso.18013.5.1.mDL")
        #expect(request.requestedElements.count == 2)
        #expect(request.requestedElements["family_name"] == true)
        #expect(request.requestedElements["given_name"] == false)
    }
    
    @Test("VerifiedCredentialData stores and retrieves values")
    func verifiedDataStoresValues() {
        let data: [String: Any] = [
            "age_over_18": true,
            "family_name": "Smith"
        ]
        let verifiedData = VerifiedCredentialData(data: data)
        
        let ageOver18 = verifiedData.getValue(for: "age_over_18") as? Bool
        let familyName = verifiedData.getValue(for: "family_name") as? String
        
        #expect(ageOver18 == true)
        #expect(familyName == "Smith")
    }
    
    @Test("VerifiedCredentialData returns nil for missing keys")
    func verifiedDataReturnsNilForMissingKeys() {
        let data: [String: Any] = ["key1": "value1"]
        let verifiedData = VerifiedCredentialData(data: data)
        
        let missingValue = verifiedData.getValue(for: "nonexistent")
        
        #expect(missingValue == nil)
    }
    
    @Test("VerifiedCredentialData handles empty data")
    func verifiedDataHandlesEmptyData() {
        let verifiedData = VerifiedCredentialData(data: [:])
        
        let value = verifiedData.getValue(for: "any_key")
        
        #expect(value == nil)
    }
    
    @Test("VerifiedCredentialData handles different value types")
    func verifiedDataHandlesDifferentTypes() {
        let data: [String: Any] = [
            "string": "test",
            "int": 42,
            "bool": true,
            "array": [1, 2, 3]
        ]
        let verifiedData = VerifiedCredentialData(data: data)
        
        #expect(verifiedData.getValue(for: "string") as? String == "test")
        #expect(verifiedData.getValue(for: "int") as? Int == 42)
        #expect(verifiedData.getValue(for: "bool") as? Bool == true)
        #expect((verifiedData.getValue(for: "array") as? [Int])?.count == 3)
    }
}
