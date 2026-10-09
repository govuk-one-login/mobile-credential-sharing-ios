import Foundation
@testable import ReaderAuthentication
import Testing

@Suite("ReaderAuthenticationOutcome Tests")
struct ReaderAuthenticationOutcomeTests {

    private static let policyURL = URL(string: "https://example.gov.uk/privacy")!
    private static let organizationName: String = "Government Digital Service"

    @Test("authenticated carries the authenticated request and supports equality")
    func authenticatedEquality() throws {
        let mdl = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.mDL")
        let aamva = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.aamva")

        let req1 = AuthenticatedReaderRequest(docRequest: mdl, privacyPolicyURL: Self.policyURL, organizationName: Self.organizationName)
        let req2 = AuthenticatedReaderRequest(docRequest: aamva, privacyPolicyURL: Self.policyURL, organizationName: Self.organizationName)

        let authenticated1 = ReaderAuthenticationOutcome.authenticated(req1)
        let authenticated2 = ReaderAuthenticationOutcome.authenticated(req1)
        let authenticated3 = ReaderAuthenticationOutcome.authenticated(req2)

        #expect(authenticated1 == authenticated2)
        #expect(authenticated1 != authenticated3)

        if case .authenticated(let extracted) = authenticated1 {
            #expect(extracted == req1)
        } else {
            Issue.record("Expected .authenticated outcome")
        }
    }

    @Test("unfulfillable equals unfulfillable and differs from authenticated")
    func unfulfillableEquality() throws {
        let req = AuthenticatedReaderRequest(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            privacyPolicyURL: Self.policyURL, organizationName: Self.organizationName
        )

        #expect(ReaderAuthenticationOutcome.unfulfillable == .unfulfillable)
        #expect(ReaderAuthenticationOutcome.unfulfillable != .authenticated(req))
    }
}
