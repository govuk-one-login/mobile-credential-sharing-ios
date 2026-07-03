import Foundation
import Networking

public final class SharingNetworkingClient: RemoteTransportProtocol {
    private let networkClient: NetworkClientProtocol

    public init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    public func fetchRequestObject(from requestURI: URL) async throws -> String {
        var request = URLRequest(url: requestURI)
        request.httpMethod = "GET"

        let data = try await networkClient
            .request(request)
            .execute()

        guard let jwt = String(data: data, encoding: .utf8) else {
            throw NetworkTransportError.encodingFailed(
                "Unable to decode response body as UTF-8 string"
            )
        }

        return jwt
    }

    public func submitResponse(
        vpToken: String,
        state: String?,
        to responseURI: URL
    ) async throws -> URL? {
        let body = buildFormBody(vpToken: vpToken, state: state)

        var request = URLRequest(url: responseURI)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )

        let responseData = try await networkClient
            .request(request)
            .execute()

        return parseRedirectURI(from: responseData)
    }

    private func buildFormBody(vpToken: String, state: String?) -> Data {
        var components: [String] = [
            "vp_token=\(formURLEncode(vpToken))"
        ]

        if let state {
            components.append("state=\(formURLEncode(state))")
        }

        let bodyString = components.joined(separator: "&")
        return Data(bodyString.utf8)
    }

    private func formURLEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(
            withAllowedCharacters: allowed
        ) ?? value
    }

    private func parseRedirectURI(from data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(
            with: data
        ) as? [String: Any],
              let uriString = json["redirect_uri"] as? String else {
            return nil
        }
        return URL(string: uriString)
    }
}
