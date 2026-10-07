import ExchangeFormat
import Foundation
import X509

/// Concrete Reader Authentication for the Holder: decodes the inbound request,
/// selects supported candidates in input order, and returns the first candidate
/// that passes both cryptographic verification (R4) and privacy-policy
/// validation (R5).
///
/// The decode, candidate selection, per-candidate checks, and failure mapping
/// all stay inside this component. Orchestration receives only the final
/// ``ReaderAuthenticationOutcome`` or a ``ReaderAuthenticationFailure``.
public struct ReaderAuthenticationVerifier: ReaderAuthenticating {

    /// Per-candidate cryptographic verifier (R4). Injected so tests can drive
    /// candidate orderings; production uses ``CandidateReaderAuthenticator``.
    private let candidateAuthenticator: ReaderAuthenticator

    /// Production initialiser. Uses the module-internal
    /// ``CandidateReaderAuthenticator`` as the per-candidate verifier.
    public init() {
        self.init(candidateAuthenticator: CandidateReaderAuthenticator())
    }

    /// Testing initialiser. Injects a per-candidate verifier so tests can drive
    /// candidate orderings without real cryptography. Internal so the
    /// ``ReaderAuthenticator`` collaborator stays inside the component boundary.
    init(candidateAuthenticator: ReaderAuthenticator) {
        self.candidateAuthenticator = candidateAuthenticator
    }

    public func authenticateDeviceRequest(
        _ request: ReaderAuthenticationVerificationRequest
    ) async throws -> ReaderAuthenticationOutcome {
        // Step 1: decode the complete decrypted bytes. Any decode failure is a
        // malformed request and is reported before any candidate work.
        let decoded: DecodedDeviceRequest
        do {
            decoded = try DecodedDeviceRequest(encodedCBOR: request.encodedDeviceRequest)
        } catch {
            throw ReaderAuthenticationFailure.malformedDeviceRequest
        }

        // Step 2: keep requests whose document type is supported, preserving
        // input order. Requested elements and namespaces are not inspected here.
        let candidates = decoded.documents.filter {
            request.supportedDocumentTypes.contains($0.itemsRequest.docType)
        }

        // Step 3: no supported request means there is nothing to authenticate.
        // Return Unfulfillable without calling R4 or R5.
        guard !candidates.isEmpty else {
            return .unfulfillable
        }

        // Step 4: verify each supported candidate in order. Return the first that
        // passes both checks; remember the last failure so it can be thrown if
        // every candidate fails.
        var lastFailure: ReaderAuthenticationFailure?
        for candidate in candidates {
            do {
                let authenticated = try await authenticate(
                    candidate: candidate,
                    untaggedSessionTranscriptBytes: request.untaggedSessionTranscriptBytes,
                    trustedReaderCertificates: request.trustedReaderCertificates
                )
                return .authenticated(authenticated)
            } catch let failure as ReaderAuthenticationFailure {
                lastFailure = failure
                continue
            }
        }

        // Step 5: every candidate failed. Throw the final candidate's failure.
        throw lastFailure ?? .malformedDeviceRequest
    }

    /// Runs R4 then R5 for one candidate. R5 runs only after R4 succeeds.
    private func authenticate(
        candidate: RequestedDocument,
        untaggedSessionTranscriptBytes: Data,
        trustedReaderCertificates: [Certificate]
    ) async throws -> AuthenticatedReaderRequest {
        let verified = try await candidateAuthenticator.verify(
            candidateDocRequest: candidate,
            untaggedSessionTranscriptBytes: untaggedSessionTranscriptBytes,
            trustedReaderCertificates: trustedReaderCertificates
        )
        return try PrivacyPolicyValidator.validate(
            docRequest: verified.docRequest,
            verifiedReaderLeaf: verified.readerCertificate
        )
    }
}
