import Foundation

public protocol RemoteTransportProtocol {
    func fetchRequestObject(from requestURI: URL) async throws -> String
    
    func submitResponse(
        vpToken: String,
        presentationSubmission: RemotePresentationSubmission,
        state: String?,
        to responseURI: URL
    ) async throws -> RemoteSubmissionResult
}
