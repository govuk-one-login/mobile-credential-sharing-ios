import CoseVerification
import ExchangeFormat
import Foundation
import X509

/// Verifies Reader Authentication for a single candidate request.
///
/// Reader Authentication proves a `DeviceRequest` came from a reader this wallet trusts and that
/// the request was not altered in transit. ISO 18013-5 uses a detached COSE_Sign1 signature
/// (`readerAuth`) over `ReaderAuthenticationBytes`, which binds the active session (the transcript)
/// to the exact request. Verifying it confirms who signed (certificate chain), what they signed
/// (the request), and which session they signed it for (the transcript, defeating replay).
///
/// `verify` runs four steps: reject a request with no signature; rebuild the exact signed bytes;
/// verify once via `CoseVerification`; return the verified request or map the failure.
///
/// This type does no privacy-metadata validation (that is R5's job, which consumes the
/// `VerifiedReaderRequest`), and keeps the verified reader certificate inside the Reader
/// Authentication boundary — it is handed only to R5, never to the wider SDK.
struct CandidateReaderAuthenticator: ReaderAuthenticator {

    /// COSE verifier for the signature check. Typed as the protocol so tests can inject a mock;
    /// production uses the concrete `CoseVerification`.
    private let coseVerifier: CoseVerifier

    init(coseVerifier: CoseVerifier = CoseVerification()) {
        self.coseVerifier = coseVerifier
    }

    func verify(
        candidateDocRequest: RequestedDocument,
        untaggedSessionTranscriptBytes: Data,
        trustedReaderCertificates: [Certificate]
    ) async throws -> VerifiedReaderRequest {
        // Step 1: no signature means there is nothing to verify. Fail fast before any other work,
        // regardless of whether trusted certificates were supplied.
        guard let rawReaderAuth = candidateDocRequest.rawReaderAuth else {
            throw ReaderAuthenticationFailure.readerAuthMissing
        }

        // Step 2: rebuild the exact bytes the reader signed — the active transcript plus the
        // request's preserved Tag 24 bytes. We never re-encode the parsed request: a COSE signature
        // covers the received bytes, and two valid CBOR encodings can differ byte-for-byte. If the
        // payload cannot even be assembled, treat it as a malformed structure.
        let readerAuthenticationBytes: ReaderAuthenticationBytes
        do {
            readerAuthenticationBytes = try ReaderAuthenticationBytes(
                untaggedSessionTranscriptBytes: untaggedSessionTranscriptBytes,
                itemsRequestBytes: candidateDocRequest.itemsRequestBytes
            )
        } catch {
            throw ReaderAuthenticationFailure.malformedReaderAuth
        }

        // Step 3: one verification call. C8 owns all crypto — COSE decode, header profile, path
        // validation against the trusted roots (it tries each root to support rotation), the
        // ReaderAuth profile, and the signature check. We pass the whole list; R4 does no root loop.
        let verificationResult: CoseVerificationResult
        do {
            verificationResult = try await coseVerifier.verifyDetached(
                coseSign1Bytes: rawReaderAuth,
                detachedPayload: readerAuthenticationBytes.bytes,
                trustedRoots: trustedReaderCertificates
            )
        } catch let failure as CoseVerificationFailure {
            throw Self.readerFailure(for: failure)
        }

        // Step 4: pair the same candidate request with the verified reader leaf certificate.
        // The leaf comes from the result (payload is nil for detached verification, as the caller
        // already owns those bytes).
        return VerifiedReaderRequest(
            docRequest: candidateDocRequest,
            readerCertificate: verificationResult.leafCertificate
        )
    }

    /// Maps a COSE verification failure to the matching Reader Authentication failure.
    ///
    /// Both `malformedCoseSign1` and `missingX5Chain` mean the `readerAuth` structure is unusable,
    /// so both become `malformedReaderAuth`. A certificate that fails the profile is treated the
    /// same as one that fails to chain to a trusted root — the reader cannot be trusted either way —
    /// so both become `untrustedReaderCertificate`. The profile-violation diagnostic is dropped; it
    /// is for C8 logging and not part of R4's failure contract.
    private static func readerFailure(
        for failure: CoseVerificationFailure
    ) -> ReaderAuthenticationFailure {
        switch failure {
        case .invalidSignature:
            return .invalidReaderSignature
        case .malformedCoseSign1:
            return .malformedReaderAuth
        case .missingX5Chain:
            return .malformedReaderAuth
        case .unsupportedAlgorithm:
            return .unsupportedReaderAuthAlgorithm
        case .untrustedCertificate:
            return .untrustedReaderCertificate
        case .certificateProfileViolation:
            return .untrustedReaderCertificate
        }
    }
}
