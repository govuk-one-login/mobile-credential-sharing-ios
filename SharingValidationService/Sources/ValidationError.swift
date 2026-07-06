import Foundation

public enum ValidationError: Error, Sendable, Equatable {
    // MARK: - URI Parsing

    case missingScheme
    case missingClientID
    case missingResponseType
    case missingNonce
    case invalidNonceCharacters
    case missingRequestURI
    case invalidRequestURI

    // MARK: - Request Object Structure

    case malformedRequestObjectHeader
    case malformedRequestObjectPayload
    case invalidTypHeader(String?)
    case invalidAudience(String?)
    case invalidResponseType(String)
    case invalidResponseMode(String)
    case missingResponseURI
    case responseURINotHTTPS
    case redirectURINotSupported
    case missingNonceInRequestObject
    case invalidNonceInRequestObject
    case clientIDMismatch
    case clientIDSANMismatch
    case invalidStateCharacters
    case missingClientMetadata

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
