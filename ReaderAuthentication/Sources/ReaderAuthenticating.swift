import Foundation

/// High-level component contract for Reader Authentication orchestration.
///
/// Authenticates decrypted `DeviceRequest` bytes, filters supported candidate
/// document types, verifies candidate signatures and privacy-policy metadata,
/// and selects the first passing candidate.
///
/// Orchestration calls this one operation rather than the per-candidate
/// verification and privacy-policy collaborators directly. The verified Reader
/// certificate and intermediate COSE results stay inside the component.
public protocol ReaderAuthenticating: Sendable {
    /// Authenticates the decrypted `DeviceRequest` bytes and selects the first
    /// candidate passing verification.
    ///
    /// - Decodes the request; a decode failure throws
    ///   ``ReaderAuthenticationFailure/malformedDeviceRequest`` before any
    ///   candidate work.
    /// - Keeps requests whose `docType` is in
    ///   ``ReaderAuthenticationVerificationRequest/supportedDocumentTypes``,
    ///   preserving input order, without inspecting requested elements.
    /// - Returns ``ReaderAuthenticationOutcome/unfulfillable`` when no supported
    ///   request remains, without verifying any candidate.
    /// - Verifies each supported candidate in order and returns the first that
    ///   passes both signature/certificate and privacy-policy checks.
    /// - Throws the last candidate's ``ReaderAuthenticationFailure`` when every
    ///   supported candidate fails.
    ///
    /// - Parameter request: The owned snapshot of inputs for this inbound
    ///   request.
    /// - Returns: ``ReaderAuthenticationOutcome/authenticated(_:)`` or
    ///   ``ReaderAuthenticationOutcome/unfulfillable``.
    /// - Throws: ``ReaderAuthenticationFailure`` if every candidate fails
    ///   verification or decoding fails.
    func authenticateDeviceRequest(
        _ request: ReaderAuthenticationVerificationRequest
    ) async throws -> ReaderAuthenticationOutcome
}

/// Outcome of Reader Authentication processing.
public enum ReaderAuthenticationOutcome: Sendable, Equatable {
    /// A candidate passed authentication and was selected.
    case authenticated(AuthenticatedReaderRequest)

    /// No candidate matched product-supported document types.
    case unfulfillable
}
