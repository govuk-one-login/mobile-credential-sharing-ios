import Foundation
@testable import SharingValidationService
import Testing

@Suite("VPRequestValidator Tests")
struct VPRequestValidatorTests {
    let sut = VPRequestValidator()

    private func makeValidURIMetadata(clientID: String = "x509_san_dns:verifier.example.com") -> URIMetadata {
        URIMetadata(
            clientID: clientID,
            clientIdentifierPrefix: .x509SanDns(identifier: "verifier.example.com"),
            responseType: "vp_token",
            nonce: "uri_nonce",
            requestMode: .byReference(requestURI: URL(string: "https://verifier.example.com/request")!)
        )
    }

    private func makeValidDCQLData() -> Data {
        let json = """
        {
            "credentials": [
                {
                    "id": "cred1",
                    "format": "mso_mdoc",
                    "meta": { "doctype_value": "org.iso.18013.5.1.mDL" },
                    "claims": [
                        { "path": ["org.iso.18013.5.1", "family_name"] },
                        { "path": ["org.iso.18013.5.1", "given_name"] }
                    ]
                }
            ]
        }
        """
        return Data(json.utf8)
    }

    private func makeValidRequestObject(
        headerTyp: String? = "oauth-authz-req+jwt",
        clientID: String? = "x509_san_dns:verifier.example.com",
        responseType: String? = "vp_token",
        responseMode: String? = "direct_post",
        responseURI: String? = "https://verifier.example.com/response",
        nonce: String? = "valid_nonce",
        state: String? = nil,
        dcqlQueryData: Data? = nil
    ) -> VPVerifiedRequestObject {
        VPVerifiedRequestObject(
            headerTyp: headerTyp,
            clientID: clientID,
            responseType: responseType,
            responseMode: responseMode,
            responseURI: responseURI,
            nonce: nonce,
            state: state,
            dcqlQueryData: dcqlQueryData ?? makeValidDCQLData()
        )
    }

    // MARK: - Happy Path

    @Test("Validates complete valid request object with direct_post mode")
    func validatesCompleteRequestDirectPost() throws {
        let requestObject = makeValidRequestObject()
        let uriMetadata = makeValidURIMetadata()

        let result = try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)

        #expect(result.responseURI.absoluteString == "https://verifier.example.com/response")
        #expect(result.nonce == "valid_nonce")
        #expect(result.state == nil)
        #expect(result.dcqlQuery.credentials.count == 1)
        #expect(result.dcqlQuery.credentials[0].format == "mso_mdoc")
    }

    @Test("Validates request with direct_post.jwt response mode")
    func validatesDirectPostJwtMode() throws {
        let requestObject = makeValidRequestObject(responseMode: "direct_post.jwt")
        let uriMetadata = makeValidURIMetadata()

        let result = try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)

        #expect(result.responseURI.absoluteString == "https://verifier.example.com/response")
    }

    @Test("Passes when state is nil")
    func passesWhenStateIsNil() throws {
        let requestObject = makeValidRequestObject(state: nil)
        let uriMetadata = makeValidURIMetadata()

        let result = try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)

        #expect(result.state == nil)
    }

    @Test("Preserves valid state in result")
    func preservesValidState() throws {
        let requestObject = makeValidRequestObject(state: "session~state.123")
        let uriMetadata = makeValidURIMetadata()

        let result = try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)

        #expect(result.state == "session~state.123")
    }

    @Test("Filters unsupported credential formats and returns only mso_mdoc")
    func filtersUnsupportedFormats() throws {
        let json = """
        {
            "credentials": [
                { "id": "cred1", "format": "jwt_vc", "claims": [] },
                { "id": "cred2", "format": "mso_mdoc", "meta": { "doctype_value": "org.iso.18013.5.1.mDL" } }
            ]
        }
        """
        let requestObject = makeValidRequestObject(dcqlQueryData: Data(json.utf8))
        let uriMetadata = makeValidURIMetadata()

        let result = try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)

        #expect(result.dcqlQuery.credentials.count == 1)
        #expect(result.dcqlQuery.credentials[0].id == "cred2")
    }

    // MARK: - Error Cases

    @Test("Throws invalidTypHeader when typ is wrong")
    func throwsInvalidTypHeaderWrongValue() {
        let requestObject = makeValidRequestObject(headerTyp: "JWT")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidTypHeader("JWT")) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidTypHeader when typ is nil")
    func throwsInvalidTypHeaderNil() {
        let requestObject = makeValidRequestObject(headerTyp: nil)
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidTypHeader(nil)) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidResponseType when not vp_token")
    func throwsInvalidResponseType() {
        let requestObject = makeValidRequestObject(responseType: "code")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidResponseType("code")) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidResponseMode when mode is fragment")
    func throwsInvalidResponseMode() {
        let requestObject = makeValidRequestObject(responseMode: "fragment")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidResponseMode("fragment")) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidResponseMode when mode is nil")
    func throwsInvalidResponseModeNil() {
        let requestObject = makeValidRequestObject(responseMode: nil)
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidResponseMode("nil")) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws missingResponseURI when response_uri nil")
    func throwsMissingResponseURI() {
        let requestObject = makeValidRequestObject(responseURI: nil)
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.missingResponseURI) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws responseURINotHTTPS when scheme is http")
    func throwsResponseURINotHTTPS() {
        let requestObject = makeValidRequestObject(responseURI: "http://verifier.example.com/response")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.responseURINotHTTPS) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws missingNonceInRequestObject when nonce nil")
    func throwsMissingNonce() {
        let requestObject = makeValidRequestObject(nonce: nil)
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.missingNonceInRequestObject) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws missingNonceInRequestObject when nonce empty")
    func throwsMissingNonceEmpty() {
        let requestObject = makeValidRequestObject(nonce: "")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.missingNonceInRequestObject) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidNonceInRequestObject when nonce has bad chars")
    func throwsInvalidNonceChars() {
        let requestObject = makeValidRequestObject(nonce: "nonce with spaces")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidNonceInRequestObject) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws clientIDMismatch when IDs differ")
    func throwsClientIDMismatch() {
        let requestObject = makeValidRequestObject(clientID: "different-client")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.clientIDMismatch) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidStateCharacters when state has invalid chars")
    func throwsInvalidStateChars() {
        let requestObject = makeValidRequestObject(state: "state with spaces")
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.invalidStateCharacters) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws missingDCQLQuery when dcqlQueryData nil")
    func throwsMissingDCQL() {
        let requestObject = makeValidRequestObject(dcqlQueryData: Data())
        let modified = VPVerifiedRequestObject(
            headerTyp: "oauth-authz-req+jwt",
            clientID: "x509_san_dns:verifier.example.com",
            responseType: "vp_token",
            responseMode: "direct_post",
            responseURI: "https://verifier.example.com/response",
            nonce: "valid_nonce",
            state: nil,
            dcqlQueryData: nil
        )
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.missingDCQLQuery) {
            try sut.validate(requestObject: modified, uriMetadata: uriMetadata)
        }
    }

    @Test("Throws invalidDCQLQuery when JSON is malformed")
    func throwsInvalidDCQLMalformed() {
        let requestObject = makeValidRequestObject(dcqlQueryData: Data("not json".utf8))
        let uriMetadata = makeValidURIMetadata()

        #expect {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        } throws: { error in
            guard let vpError = error as? VPValidationError,
                  case .invalidDCQLQuery = vpError else {
                return false
            }
            return true
        }
    }

    @Test("Throws noSupportedCredentialQueries when no mso_mdoc format")
    func throwsNoSupportedFormats() {
        let json = """
        { "credentials": [{ "id": "c1", "format": "jwt_vc" }] }
        """
        let requestObject = makeValidRequestObject(dcqlQueryData: Data(json.utf8))
        let uriMetadata = makeValidURIMetadata()

        #expect(throws: VPValidationError.noSupportedCredentialQueries) {
            try sut.validate(requestObject: requestObject, uriMetadata: uriMetadata)
        }
    }
}
