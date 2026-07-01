import Foundation

public struct VPURIParser {
    public init() {}

    public func parse(uri: URL) throws(VPValidationError) -> URIMetadata {
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

        let request = params["request"]
        let requestURI = params["request_uri"]

        let hasRequest = request != nil && !request!.isEmpty
        let hasRequestURI = requestURI != nil && !requestURI!.isEmpty

        guard hasRequest || hasRequestURI else {
            throw .missingRequestAndRequestURI
        }

        guard !(hasRequest && hasRequestURI) else {
            throw .bothRequestAndRequestURIPresent
        }

        let requestMode: URIMetadata.RequestMode
        if hasRequest {
            requestMode = .byValue(jwt: request!)
        } else {
            guard let url = URL(string: requestURI!) else {
                throw .missingRequestAndRequestURI
            }
            requestMode = .byReference(requestURI: url)
        }

        let clientIdentifierPrefix = ClientIdentifierPrefix.parse(clientID: clientID)

        return URIMetadata(
            clientID: clientID,
            clientIdentifierPrefix: clientIdentifierPrefix,
            responseType: responseType,
            nonce: nonce,
            requestMode: requestMode
        )
    }

    static let asciiURLSafeCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    static func isASCIIURLSafe(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { asciiURLSafeCharacters.contains($0) }
    }
}
