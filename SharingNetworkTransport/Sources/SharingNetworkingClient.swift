import Foundation
import Networking

/// A `struct` with nonisolated methods, satisfying `RemoteTransportProtocol`'s `Sendable`
/// requirement without any escape hatch.
///
/// The GDS `Networking` types are not `Sendable`: `NetworkClientProtocol.request(_:)` returns a
/// non-`Sendable` `RequestBuilder` whose `execute()` is `nonisolated async`. Chaining them from any
/// *isolated* context (an actor or `@MainActor`) would "send" that builder across isolation domains.
/// Keeping this type a value type with nonisolated methods means the whole request/execute chain runs
/// in a single nonisolated context, so nothing is ever sent. It stays `Sendable` by storing a
/// `@Sendable` factory closure (a fresh client per call) instead of a non-`Sendable` client reference.
public struct SharingNetworkingClient: RemoteTransportProtocol {
    private let makeNetworkClient: @Sendable () -> NetworkClientProtocol

    public init(networkClient: @escaping @Sendable () -> NetworkClientProtocol = { NetworkClient() }) {
        self.makeNetworkClient = networkClient
    }

    public func fetchRequestObject(from requestURI: URL) async throws -> String {
        var request = URLRequest(url: requestURI)
        request.httpMethod = "GET"

        let data = try await makeNetworkClient()
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

        let responseData = try await makeNetworkClient()
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
