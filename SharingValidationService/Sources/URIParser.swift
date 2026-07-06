import Foundation

public struct URIParser {
    static let asciiURLSafeCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    public init() {}

    public func parse(uri: URL) throws(ValidationError) -> URIMetadata {
        guard uri.scheme?.lowercased() == "openid4vp" else {
            throw .missingScheme
        }

        guard let components = URLComponents(url: uri, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw .missingClientID
        }

        let params = Dictionary(
            queryItems.map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { first, _ in first }
        )

        guard let clientID = params["client_id"], !clientID.isEmpty else {
            throw .missingClientID
        }

        guard let responseType = params["response_type"], !responseType.isEmpty else {
            throw .missingResponseType
        }

        guard let nonce = params["nonce"], !nonce.isEmpty else {
            throw .missingNonce
        }

        guard Self.isASCIIURLSafe(nonce) else {
            throw .invalidNonceCharacters
        }

        guard let requestURIString = params["request_uri"], !requestURIString.isEmpty else {
            throw .missingRequestURI
        }

        guard let requestURI = URL(string: requestURIString),
              requestURI.scheme != nil,
              requestURI.host != nil else {
            throw .invalidRequestURI
        }

        let clientIdentifierPrefix = ClientIdentifierPrefix.parse(clientID: clientID)

        return URIMetadata(
            clientID: clientID,
            clientIdentifierPrefix: clientIdentifierPrefix,
            responseType: responseType,
            nonce: nonce,
            requestURI: requestURI
        )
    }

    static func isASCIIURLSafe(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { asciiURLSafeCharacters.contains($0) }
    }
}
