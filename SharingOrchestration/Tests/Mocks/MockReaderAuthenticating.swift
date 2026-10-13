import ExchangeFormat
import Foundation
import ReaderAuthentication

/// A test double for `ReaderAuthenticating` that returns a stubbed outcome or
/// throws a stubbed failure, so orchestrator tests can drive each ReaderAuth
/// branch without real cryptography.
final class MockReaderAuthenticating: ReaderAuthenticating, @unchecked Sendable {
    var stubbedOutcome: ReaderAuthenticationOutcome
    var errorToThrow: ReaderAuthenticationFailure?
    private(set) var didCallAuthenticate = false
    private(set) var passedRequest: ReaderAuthenticationVerificationRequest?

    init(
        stubbedOutcome: ReaderAuthenticationOutcome = .unfulfillable,
        errorToThrow: ReaderAuthenticationFailure? = nil
    ) {
        self.stubbedOutcome = stubbedOutcome
        self.errorToThrow = errorToThrow
    }

    func authenticateDeviceRequest(
        _ request: ReaderAuthenticationVerificationRequest
    ) async throws -> ReaderAuthenticationOutcome {
        didCallAuthenticate = true
        passedRequest = request
        if let errorToThrow {
            throw errorToThrow
        }
        return stubbedOutcome
    }
}
