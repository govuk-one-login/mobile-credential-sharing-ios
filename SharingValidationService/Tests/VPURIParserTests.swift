import Foundation
@testable import SharingValidationService
import Testing

@Suite("VPURIParser Tests")
struct VPURIParserTests {
    let sut = VPURIParser()

    // MARK: - Happy Path

    @Test("Parses valid by-value URI with all required parameters")
    func parsesValidByValueURI() throws {
        let uri = URL(string: "openid4vp://?client_id=verifier.example.com&response_type=vp_token&nonce=abc123&request=eyJhbGciOiJSUzI1NiJ9.test.sig")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientID == "verifier.example.com")
        #expect(result.responseType == "vp_token")
        #expect(result.nonce == "abc123")
        if case .byValue(let jwt) = result.requestMode {
            #expect(jwt == "eyJhbGciOiJSUzI1NiJ9.test.sig")
        } else {
            Issue.record("Expected byValue request mode")
        }
    }

    @Test("Parses valid by-reference URI with request_uri")
    func parsesValidByReferenceURI() throws {
        let uri = URL(string: "openid4vp://?client_id=verifier.example.com&response_type=vp_token&nonce=n0nce_value-123.test~ok&request_uri=https%3A%2F%2Fverifier.example.com%2Frequest%2F123")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientID == "verifier.example.com")
        #expect(result.nonce == "n0nce_value-123.test~ok")
        if case .byReference(let requestURI) = result.requestMode {
            #expect(requestURI.absoluteString == "https://verifier.example.com/request/123")
        } else {
            Issue.record("Expected byReference request mode")
        }
    }

    // MARK: - Client Identifier Prefix

    @Test("Parses URI with x509_san_dns client_id prefix")
    func parsesX509SanDnsPrefix() throws {
        let uri = URL(string: "openid4vp://?client_id=x509_san_dns%3Averifier.example.com&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .x509SanDns(identifier: "verifier.example.com"))
    }

    @Test("Parses URI with x509_san_uri client_id prefix")
    func parsesX509SanUriPrefix() throws {
        let uri = URL(string: "openid4vp://?client_id=x509_san_uri%3Ahttps%3A%2F%2Fverifier.example.com&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .x509SanUri(identifier: "https://verifier.example.com"))
    }

    @Test("Parses URI with did client_id prefix")
    func parsesDidPrefix() throws {
        let uri = URL(string: "openid4vp://?client_id=did%3Aexample%3A123abc&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .did(identifier: "example:123abc"))
    }

    @Test("Parses URI with redirect_uri client_id prefix")
    func parsesRedirectUriPrefix() throws {
        let uri = URL(string: "openid4vp://?client_id=redirect_uri%3Ahttps%3A%2F%2Fexample.com%2Fcb&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .redirectUri(identifier: "https://example.com/cb"))
    }

    @Test("Parses URI with verifier_attestation client_id prefix")
    func parsesVerifierAttestationPrefix() throws {
        let uri = URL(string: "openid4vp://?client_id=verifier_attestation%3Averifier-id-xyz&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .verifierAttestation(identifier: "verifier-id-xyz"))
    }

    @Test("Parses URI with pre-registered client_id (no known prefix)")
    func parsesPreRegisteredClientID() throws {
        let uri = URL(string: "openid4vp://?client_id=my-verifier-app&response_type=vp_token&nonce=abc&request=jwt")!

        let result = try sut.parse(uri: uri)

        #expect(result.clientIdentifierPrefix == .preRegistered(fullClientID: "my-verifier-app"))
    }

    // MARK: - Error Cases

    @Test("Throws missingScheme for non-openid4vp URI")
    func throwsMissingSchemeForWrongScheme() {
        let uri = URL(string: "https://verifier.example.com?client_id=x&response_type=vp_token&nonce=abc&request=jwt")!

        #expect(throws: VPValidationError.missingScheme) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws missingClientID when client_id absent")
    func throwsMissingClientID() {
        let uri = URL(string: "openid4vp://?response_type=vp_token&nonce=abc&request=jwt")!

        #expect(throws: VPValidationError.missingClientID) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws missingClientID when client_id is empty")
    func throwsMissingClientIDWhenEmpty() {
        let uri = URL(string: "openid4vp://?client_id=&response_type=vp_token&nonce=abc&request=jwt")!

        #expect(throws: VPValidationError.missingClientID) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws missingResponseType when response_type absent")
    func throwsMissingResponseType() {
        let uri = URL(string: "openid4vp://?client_id=verifier&nonce=abc&request=jwt")!

        #expect(throws: VPValidationError.missingResponseType) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws missingNonce when nonce absent")
    func throwsMissingNonce() {
        let uri = URL(string: "openid4vp://?client_id=verifier&response_type=vp_token&request=jwt")!

        #expect(throws: VPValidationError.missingNonce) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws invalidNonceCharacters for nonce with spaces")
    func throwsInvalidNonceWithSpaces() {
        let uri = URL(string: "openid4vp://?client_id=verifier&response_type=vp_token&nonce=has%20space&request=jwt")!

        #expect(throws: VPValidationError.invalidNonceCharacters) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws invalidNonceCharacters for nonce with special characters")
    func throwsInvalidNonceWithSpecialChars() {
        let uri = URL(string: "openid4vp://?client_id=verifier&response_type=vp_token&nonce=bad%40nonce&request=jwt")!

        #expect(throws: VPValidationError.invalidNonceCharacters) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws missingRequestAndRequestURI when neither present")
    func throwsMissingRequestAndRequestURI() {
        let uri = URL(string: "openid4vp://?client_id=verifier&response_type=vp_token&nonce=abc")!

        #expect(throws: VPValidationError.missingRequestAndRequestURI) {
            try sut.parse(uri: uri)
        }
    }

    @Test("Throws bothRequestAndRequestURIPresent when both present")
    func throwsBothPresent() {
        let uri = URL(string: "openid4vp://?client_id=verifier&response_type=vp_token&nonce=abc&request=jwt&request_uri=https%3A%2F%2Fexample.com")!

        #expect(throws: VPValidationError.bothRequestAndRequestURIPresent) {
            try sut.parse(uri: uri)
        }
    }

    // MARK: - Nonce Validation Helper

    @Test("isASCIIURLSafe accepts alphanumeric with -._~")
    func acceptsValidNonceChars() {
        #expect(VPURIParser.isASCIIURLSafe("abcXYZ0123-._~"))
    }

    @Test("isASCIIURLSafe rejects spaces")
    func rejectsSpaces() {
        #expect(!VPURIParser.isASCIIURLSafe("has space"))
    }

    @Test("isASCIIURLSafe rejects @#$% characters")
    func rejectsSpecialCharacters() {
        #expect(!VPURIParser.isASCIIURLSafe("bad@#$%"))
    }

    @Test("isASCIIURLSafe rejects forward slash")
    func rejectsForwardSlash() {
        #expect(!VPURIParser.isASCIIURLSafe("path/segment"))
    }
}
