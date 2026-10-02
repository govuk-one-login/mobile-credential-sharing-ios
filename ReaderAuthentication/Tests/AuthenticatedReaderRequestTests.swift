import Foundation
@testable import ReaderAuthentication
import Testing

@Suite("AuthenticatedReaderRequest Tests")
struct AuthenticatedReaderRequestTests {

    private static let policyURL1 = URL(string: "https://example.gov.uk/privacy")!
    private static let policyURL2 = URL(string: "https://example.gov.uk/other")!
    private static let organizationName: String = "Government Digital Service"

    @Test("holds properties and supports equality")
    func holdsPropertiesAndEquality() throws {
        let docRequest1 = try ReaderAuthFixtures.requestedDocument()
        let docRequest2 = try ReaderAuthFixtures.requestedDocument()

        let req1 = AuthenticatedReaderRequest(docRequest: docRequest1, privacyPolicyURL: Self.policyURL1, organizationName: Self.organizationName)
        let req2 = AuthenticatedReaderRequest(docRequest: docRequest2, privacyPolicyURL: Self.policyURL1, organizationName: Self.organizationName)

        #expect(req1.docRequest == docRequest1)
        #expect(req1.privacyPolicyURL == Self.policyURL1)
        #expect(req1 == req2)
    }

    @Test("differs when the privacy-policy URL differs")
    func differsByURL() throws {
        let docRequest = try ReaderAuthFixtures.requestedDocument()

        let req1 = AuthenticatedReaderRequest(docRequest: docRequest, privacyPolicyURL: Self.policyURL1, organizationName: Self.organizationName)
        let req2 = AuthenticatedReaderRequest(docRequest: docRequest, privacyPolicyURL: Self.policyURL2, organizationName: Self.organizationName)

        #expect(req1 != req2)
    }
}
