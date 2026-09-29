import Foundation
@testable import ReaderAuthentication
import Testing

@Suite("ReaderAuthenticationOutcome Tests")
struct ReaderAuthenticationOutcomeTests {

    private static let policyURL = URL(string: "https://example.gov.uk/privacy")!

    @Test("success carries the authenticated request and supports equality")
    func successEquality() throws {
        let mdl = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.mDL")
        let aamva = try ReaderAuthFixtures.requestedDocument(docType: "org.iso.18013.5.1.aamva")

        let req1 = AuthenticatedReaderRequest(docRequest: mdl, privacyPolicyURL: Self.policyURL)
        let req2 = AuthenticatedReaderRequest(docRequest: aamva, privacyPolicyURL: Self.policyURL)

        let success1 = ReaderAuthenticationOutcome.success(req1)
        let success2 = ReaderAuthenticationOutcome.success(req1)
        let success3 = ReaderAuthenticationOutcome.success(req2)

        #expect(success1 == success2)
        #expect(success1 != success3)

        if case .success(let extracted) = success1 {
            #expect(extracted == req1)
        } else {
            Issue.record("Expected .success outcome")
        }
    }

    @Test("unfulfillable equals unfulfillable and differs from success")
    func unfulfillableEquality() throws {
        let req = AuthenticatedReaderRequest(
            docRequest: try ReaderAuthFixtures.requestedDocument(),
            privacyPolicyURL: Self.policyURL
        )

        #expect(ReaderAuthenticationOutcome.unfulfillable == .unfulfillable)
        #expect(ReaderAuthenticationOutcome.unfulfillable != .success(req))
    }
}
