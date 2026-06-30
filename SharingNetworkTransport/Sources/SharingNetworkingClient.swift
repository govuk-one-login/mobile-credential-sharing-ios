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
        presentationSubmission: RemotePresentationSubmission,
        state: String?,
        to responseURI: URL
    ) async throws -> RemoteSubmissionResult {
        let body = try buildFormBody(
            vpToken: vpToken,
            presentationSubmission: presentationSubmission,
            state: state
        )

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

        return RemoteSubmissionResult(
            redirectURI: parseRedirectURI(from: responseData)
        )
    }

    private func buildFormBody(
        vpToken: String,
        presentationSubmission: RemotePresentationSubmission,
        state: String?
    ) throws -> Data {
        let submissionJSON: Data
        do {
            submissionJSON = try JSONEncoder().encode(presentationSubmission)
        } catch {
            throw NetworkTransportError.encodingFailed(
                "Failed to encode presentation_submission"
            )
        }

        guard let submissionString = String(
            data: submissionJSON,
            encoding: .utf8
        ) else {
            throw NetworkTransportError.encodingFailed(
                "Unable to convert presentation_submission to UTF-8"
            )
        }

        var components: [String] = [
            "vp_token=\(formURLEncode(vpToken))",
            "presentation_submission=\(formURLEncode(submissionString))"
        ]

        if let state {
            components.append("state=\(formURLEncode(state))")
        }

        let bodyString = components.joined(separator: "&")

        guard let bodyData = bodyString.data(using: .utf8) else {
            throw NetworkTransportError.encodingFailed(
                "Unable to encode form body as UTF-8"
            )
        }

        return bodyData
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
