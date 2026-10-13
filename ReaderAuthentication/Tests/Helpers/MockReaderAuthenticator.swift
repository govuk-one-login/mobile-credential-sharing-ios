import ExchangeFormat
import Foundation
@testable import ReaderAuthentication
import X509

/// A per-candidate `ReaderAuthenticator` (R4) stub for driving the candidate
/// loop in `ReaderAuthenticationVerifier` tests.
///
/// Each candidate is matched by its `docType`. A matched outcome is either:
/// - `.throwR4(failure)` — R4 fails for this candidate (e.g. an invalid
///   signature), or
/// - `.verified(leaf)` — R4 succeeds and hands the loop a `VerifiedReaderRequest`
///   bound to `leaf`. The loop then runs the real `PrivacyPolicyValidator`
///   against that leaf, so a leaf with valid SIA passes R5 and a leaf without
///   SIA fails R5 with `privacyPolicyURLInvalid`.
///
/// Any unmatched docType throws `malformedReaderAuth` to make a missing stub
/// obvious in a failing test.
final class MockReaderAuthenticator: ReaderAuthenticator, @unchecked Sendable {

    enum Outcome {
        case throwR4(ReaderAuthenticationFailure)
        case verified(leaf: Certificate)
    }

    /// Outcome keyed by candidate docType.
    private let outcomes: [String: Outcome]

    /// The docTypes passed to `verify`, in call order — asserts short-circuit
    /// behaviour (later candidates must not be evaluated after a pass).
    private(set) var evaluatedDocTypes: [String] = []

    init(outcomes: [String: Outcome]) {
        self.outcomes = outcomes
    }

    func verify(
        candidateDocRequest: RequestedDocument,
        untaggedSessionTranscriptBytes: Data,
        trustedReaderCertificates: [Certificate]
    ) async throws -> VerifiedReaderRequest {
        let docType = candidateDocRequest.itemsRequest.docType
        evaluatedDocTypes.append(docType)

        switch outcomes[docType] {
        case .throwR4(let failure):
            throw failure
        case .verified(let leaf):
            return VerifiedReaderRequest(docRequest: candidateDocRequest, readerCertificate: leaf)
        case .none:
            throw ReaderAuthenticationFailure.malformedReaderAuth
        }
    }
}
