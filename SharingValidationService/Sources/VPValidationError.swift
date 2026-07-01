import Foundation

public enum VPValidationError: Error, Sendable, Equatable {
    // MARK: - URI Parsing

    case missingScheme
    case missingClientID
    case missingResponseType
    case missingNonce
    case invalidNonceCharacters
    case missingRequestAndRequestURI
    case bothRequestAndRequestURIPresent

    // MARK: - Request Object Structure

    case invalidTypHeader(String?)
    case invalidResponseType(String)
    case invalidResponseMode(String)
    case missingResponseURI
    case responseURINotHTTPS
    case missingNonceInRequestObject
    case invalidNonceInRequestObject
    case clientIDMismatch
    case invalidStateCharacters

    // MARK: - DCQL

    case missingDCQLQuery
    case invalidDCQLQuery(String)
    case noSupportedCredentialQueries

    public var oid4vpErrorCode: String {
        switch self {
        case .noSupportedCredentialQueries:
            "vp_formats_not_supported"
        case .invalidResponseType:
            "unsupported_response_type"
        case .invalidResponseMode:
            "unsupported_response_mode"
        default:
            "invalid_request"
        }
    }
}
