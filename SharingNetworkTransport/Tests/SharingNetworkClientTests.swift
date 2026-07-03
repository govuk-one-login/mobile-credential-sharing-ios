import Foundation
import Networking
@testable import SharingNetworkTransport
import Testing

@Suite("SharingNetworkingClient Tests")
struct SharingNetworkingClientTests {

    // MARK: - fetchRequestObject

    @Test("fetchRequestObject returns JWT string on success")
    func fetchSuccess() async throws {
        let expectedJWT = "eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJ2ZXJpZmllciJ9.sig"
        let mock = MockNetworkClient(responseData: Data(expectedJWT.utf8))

        let client = SharingNetworkingClient(networkClient: mock)
        let result = try await client.fetchRequestObject(
            from: URL(string: "https://verifier.example.com/request/abc")!
        )

        #expect(result == expectedJWT)
    }

    @Test("fetchRequestObject passes correct URL with GET method")
    func fetchPassesCorrectRequest() async throws {
        let mock = MockNetworkClient(responseData: Data("jwt".utf8))
        let url = URL(string: "https://verifier.example.com/request/123")!

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.fetchRequestObject(from: url)

        let captured = mock.capturedRequests.first
        #expect(captured?.url == url)
        #expect(captured?.httpMethod == "GET")
    }

    @Test("fetchRequestObject throws encodingFailed for invalid UTF-8")
    func fetchInvalidUTF8() async throws {
        let invalidBytes: [UInt8] = [0xFF, 0xFE, 0xFD]
        let mock = MockNetworkClient(responseData: Data(invalidBytes))

        let client = SharingNetworkingClient(networkClient: mock)

        await #expect(throws: NetworkTransportError.self) {
            try await client.fetchRequestObject(
                from: URL(string: "https://verifier.example.com/request")!
            )
        }
    }

    @Test("fetchRequestObject propagates network error")
    func fetchNetworkError() async throws {
        let mock = MockNetworkClient(error: URLError(.notConnectedToInternet))

        let client = SharingNetworkingClient(networkClient: mock)

        await #expect(throws: (any Error).self) {
            try await client.fetchRequestObject(
                from: URL(string: "https://verifier.example.com/request")!
            )
        }
    }

    // MARK: - submitResponse

    @Test("submitResponse returns redirect URI from response body")
    func submitWithRedirect() async throws {
        let json = """
        {"redirect_uri":"https://verifier.example.com/callback"}
        """
        let mock = MockNetworkClient(responseData: Data(json.utf8))

        let client = SharingNetworkingClient(networkClient: mock)
        let redirectURI = try await client.submitResponse(
            vpToken: "encrypted.jwe.token",
            state: "state-123",
            to: URL(string: "https://verifier.example.com/response")!
        )

        #expect(redirectURI == URL(string: "https://verifier.example.com/callback"))
    }

    @Test("submitResponse returns nil when no redirect URI in response")
    func submitWithoutRedirect() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        let redirectURI = try await client.submitResponse(
            vpToken: "token",
            state: nil,
            to: URL(string: "https://verifier.example.com/response")!
        )

        #expect(redirectURI == nil)
    }

    @Test("submitResponse sends POST with correct URL and Content-Type")
    func submitPassesCorrectRequest() async throws {
        let mock = MockNetworkClient(responseData: Data())
        let url = URL(string: "https://verifier.example.com/response")!

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "token",
            state: nil,
            to: url
        )

        let captured = mock.capturedRequests.first
        #expect(captured?.url == url)
        #expect(captured?.httpMethod == "POST")
        #expect(
            captured?.value(forHTTPHeaderField: "Content-Type")
                == "application/x-www-form-urlencoded"
        )
    }

    @Test("submitResponse form body contains vp_token")
    func submitFormBodyFields() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "my-token",
            state: nil,
            to: URL(string: "https://verifier.example.com/response")!
        )

        let body = mock.capturedRequests.first?.httpBody
        let bodyString = String(data: body!, encoding: .utf8)!
        #expect(bodyString.contains("vp_token=my-token"))
    }

    @Test("submitResponse does not include presentation_submission")
    func submitNoPresentationSubmission() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "token",
            state: nil,
            to: URL(string: "https://verifier.example.com/response")!
        )

        let body = mock.capturedRequests.first?.httpBody
        let bodyString = String(data: body!, encoding: .utf8)!
        #expect(!bodyString.contains("presentation_submission"))
    }

    @Test("submitResponse includes state in form body when provided")
    func submitIncludesState() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "token",
            state: "xyz",
            to: URL(string: "https://verifier.example.com/response")!
        )

        let body = mock.capturedRequests.first?.httpBody
        let bodyString = String(data: body!, encoding: .utf8)!
        #expect(bodyString.contains("state=xyz"))
    }

    @Test("submitResponse omits state from form body when nil")
    func submitOmitsState() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "token",
            state: nil,
            to: URL(string: "https://verifier.example.com/response")!
        )

        let body = mock.capturedRequests.first?.httpBody
        let bodyString = String(data: body!, encoding: .utf8)!
        #expect(!bodyString.contains("state="))
    }

    @Test("submitResponse percent-encodes special characters in vp_token")
    func submitPercentEncodes() async throws {
        let mock = MockNetworkClient(responseData: Data())

        let client = SharingNetworkingClient(networkClient: mock)
        _ = try await client.submitResponse(
            vpToken: "a+b/c=d",
            state: nil,
            to: URL(string: "https://verifier.example.com/response")!
        )

        let body = mock.capturedRequests.first?.httpBody
        let bodyString = String(data: body!, encoding: .utf8)!
        #expect(bodyString.contains("vp_token=a%2Bb%2Fc%3Dd"))
    }

    @Test("submitResponse propagates network error")
    func submitNetworkError() async throws {
        let mock = MockNetworkClient(error: URLError(.timedOut))

        let client = SharingNetworkingClient(networkClient: mock)

        await #expect(throws: (any Error).self) {
            try await client.submitResponse(
                vpToken: "token",
                state: nil,
                to: URL(string: "https://verifier.example.com/response")!
            )
        }
    }
}

private final class MockNetworkClient: NetworkClientProtocol {
    let responseData: Data
    let error: (any Error)?
    private(set) var capturedRequests: [URLRequest] = []

    init(responseData: Data = Data(), error: (any Error)? = nil) {
        self.responseData = responseData
        self.error = error
    }

    func request(_ request: URLRequest) -> RequestBuilder {
        capturedRequests.append(request)
        return RequestBuilder(client: self, request: request)
    }

    func makeRequest(_ request: NetworkRequest) async throws -> Data {
        if let error { throw error }
        return responseData
    }
}
