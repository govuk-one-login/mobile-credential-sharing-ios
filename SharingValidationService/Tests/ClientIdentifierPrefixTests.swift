import Foundation
@testable import SharingValidationService
import Testing

@Suite("ClientIdentifierPrefix Parsing Tests")
struct ClientIdentifierPrefixTests {

    @Test("Parses x509_san_dns prefix")
    func parsesX509SanDns() {
        let result = ClientIdentifierPrefix.parse(clientID: "x509_san_dns:verifier.example.com")

        #expect(result == .x509SanDns(identifier: "verifier.example.com"))
    }

    @Test("Parses x509_san_uri prefix")
    func parsesX509SanUri() {
        let result = ClientIdentifierPrefix.parse(clientID: "x509_san_uri:https://verifier.example.com")

        #expect(result == .x509SanUri(identifier: "https://verifier.example.com"))
    }

    @Test("Parses did prefix")
    func parsesDid() {
        let result = ClientIdentifierPrefix.parse(clientID: "did:web:verifier.example.com")

        #expect(result == .did(identifier: "web:verifier.example.com"))
    }

    @Test("Parses redirect_uri prefix")
    func parsesRedirectUri() {
        let result = ClientIdentifierPrefix.parse(clientID: "redirect_uri:https://example.com/callback")

        #expect(result == .redirectUri(identifier: "https://example.com/callback"))
    }

    @Test("Parses verifier_attestation prefix")
    func parsesVerifierAttestation() {
        let result = ClientIdentifierPrefix.parse(clientID: "verifier_attestation:my-verifier-id")

        #expect(result == .verifierAttestation(identifier: "my-verifier-id"))
    }

    @Test("Returns preRegistered for unknown prefix pattern")
    func returnsPreRegisteredForUnknownPrefix() {
        let result = ClientIdentifierPrefix.parse(clientID: "unknown_prefix:some-value")

        #expect(result == .preRegistered(fullClientID: "unknown_prefix:some-value"))
    }

    @Test("Returns preRegistered for plain string client ID")
    func returnsPreRegisteredForPlainString() {
        let result = ClientIdentifierPrefix.parse(clientID: "my-verifier-app")

        #expect(result == .preRegistered(fullClientID: "my-verifier-app"))
    }

    @Test("Handles empty identifier after prefix")
    func handlesEmptyIdentifierAfterPrefix() {
        let result = ClientIdentifierPrefix.parse(clientID: "x509_san_dns:")

        #expect(result == .x509SanDns(identifier: ""))
    }
}
