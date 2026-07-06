import Foundation
@testable import SharingValidationService
import Testing

@Suite("ValidationError Tests")
struct ValidationErrorTests {

    @Test("oid4vpErrorCode returns invalid_request for URI parsing errors")
    func invalidRequestForURIErrors() {
        #expect(ValidationError.missingScheme.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingClientID.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingResponseType.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingNonce.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.invalidNonceCharacters.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingRequestURI.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.invalidRequestURI.oid4vpErrorCode == "invalid_request")
    }

    @Test("oid4vpErrorCode returns unsupported_response_type for wrong response_type")
    func unsupportedResponseType() {
        #expect(ValidationError.invalidResponseType("code").oid4vpErrorCode == "unsupported_response_type")
    }

    @Test("oid4vpErrorCode returns unsupported_response_mode for wrong response_mode")
    func unsupportedResponseMode() {
        #expect(ValidationError.invalidResponseMode("fragment").oid4vpErrorCode == "unsupported_response_mode")
    }

    @Test("oid4vpErrorCode returns vp_formats_not_supported when no supported formats")
    func vpFormatsNotSupported() {
        #expect(ValidationError.noSupportedCredentialQueries.oid4vpErrorCode == "vp_formats_not_supported")
    }

    @Test("oid4vpErrorCode returns invalid_request for request object errors")
    func invalidRequestForRequestObjectErrors() {
        #expect(ValidationError.invalidTypHeader("JWT").oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingResponseURI.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.responseURINotHTTPS.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingNonceInRequestObject.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.invalidNonceInRequestObject.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.clientIDMismatch.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.invalidStateCharacters.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.missingDCQLQuery.oid4vpErrorCode == "invalid_request")
        #expect(ValidationError.invalidDCQLQuery("reason").oid4vpErrorCode == "invalid_request")
    }

    @Test("VPValidationError cases are Equatable")
    func equatable() {
        #expect(ValidationError.missingScheme == ValidationError.missingScheme)
        #expect(ValidationError.invalidResponseType("a") == ValidationError.invalidResponseType("a"))
        #expect(ValidationError.invalidResponseType("a") != ValidationError.invalidResponseType("b"))
        #expect(ValidationError.invalidTypHeader(nil) == ValidationError.invalidTypHeader(nil))
        #expect(ValidationError.invalidTypHeader("x") != ValidationError.invalidTypHeader(nil))
    }
}
