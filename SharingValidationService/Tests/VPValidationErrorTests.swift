import Foundation
@testable import SharingValidationService
import Testing

@Suite("VPValidationError Tests")
struct VPValidationErrorTests {

    @Test("oid4vpErrorCode returns invalid_request for URI parsing errors")
    func invalidRequestForURIErrors() {
        #expect(VPValidationError.missingScheme.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingClientID.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingResponseType.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingNonce.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.invalidNonceCharacters.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingRequestAndRequestURI.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.bothRequestAndRequestURIPresent.oid4vpErrorCode == "invalid_request")
    }

    @Test("oid4vpErrorCode returns unsupported_response_type for wrong response_type")
    func unsupportedResponseType() {
        #expect(VPValidationError.invalidResponseType("code").oid4vpErrorCode == "unsupported_response_type")
    }

    @Test("oid4vpErrorCode returns unsupported_response_mode for wrong response_mode")
    func unsupportedResponseMode() {
        #expect(VPValidationError.invalidResponseMode("fragment").oid4vpErrorCode == "unsupported_response_mode")
    }

    @Test("oid4vpErrorCode returns vp_formats_not_supported when no supported formats")
    func vpFormatsNotSupported() {
        #expect(VPValidationError.noSupportedCredentialQueries.oid4vpErrorCode == "vp_formats_not_supported")
    }

    @Test("oid4vpErrorCode returns invalid_request for request object errors")
    func invalidRequestForRequestObjectErrors() {
        #expect(VPValidationError.invalidTypHeader("JWT").oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingResponseURI.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.responseURINotHTTPS.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingNonceInRequestObject.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.invalidNonceInRequestObject.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.clientIDMismatch.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.invalidStateCharacters.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.missingDCQLQuery.oid4vpErrorCode == "invalid_request")
        #expect(VPValidationError.invalidDCQLQuery("reason").oid4vpErrorCode == "invalid_request")
    }

    @Test("VPValidationError cases are Equatable")
    func equatable() {
        #expect(VPValidationError.missingScheme == VPValidationError.missingScheme)
        #expect(VPValidationError.invalidResponseType("a") == VPValidationError.invalidResponseType("a"))
        #expect(VPValidationError.invalidResponseType("a") != VPValidationError.invalidResponseType("b"))
        #expect(VPValidationError.invalidTypHeader(nil) == VPValidationError.invalidTypHeader(nil))
        #expect(VPValidationError.invalidTypHeader("x") != VPValidationError.invalidTypHeader(nil))
    }
}
