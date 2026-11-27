@testable import CRLProvider
import Foundation
@testable import mobile_credential_sharing_ios
import Testing

/// These run inside the host app, so `Bundle.main` is the app bundle. They prove the real
/// `CredentialSharingCRL.plist` is bundled and parses.
struct CRLConfigurationBundleTests {
    @Test("The test app bundles CredentialSharingCRL.plist with the pinned GDS CRL URLs")
    func appBundlesPinnedCRLURLs() throws {
        let sut = try CRLProvider()

        #expect(sut.prefetchURLs.map(\.absoluteString) == [
            "http://root.verifier-root-ca.integration.account.gov.uk/crl/3689017a-d5f2-4762-b518-afb86983dd25.crl",
            "http://dvs.verifier-ca.integration.account.gov.uk/crl/85b2ae92-97ab-406b-93b2-f765795de390.crl"
        ])
    }
}
