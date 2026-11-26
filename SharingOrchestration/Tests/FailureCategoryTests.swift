@testable import SharingOrchestration
import SharingPrerequisiteGate
import Testing

@Suite("FailureCategory mapping Tests")
struct FailureCategoryTests {

    // MARK: - SessionError -> FailureCategory

    @Test(
        "Only .generic(String) and .unknown map to the generic category",
        arguments: [
            SessionError.generic("Something broke"),
            SessionError.generic(""),
            SessionError.unknown
        ]
    )
    func genericErrorsMapToGeneric(error: SessionError) {
        #expect(FailureCategory(error) == .generic)
    }

    @Test("readerAuthenticationFailed maps to the readerAuthentication category")
    func readerAuthFailureMapsToReaderAuthentication() {
        #expect(
            FailureCategory(.readerAuthenticationFailed(reason: "untrustedReaderCertificate"))
                == .readerAuthentication
        )
    }

    @Test(
        "Every other SessionError stays on its existing screen via .legacy",
        arguments: [
            SessionError.unrecoverablePrerequisite(.bluetooth(.authorizationDenied)),
            SessionError.unrecoverablePrerequisite(.camera(.authorizationDenied)),
            SessionError.incorrectSessionState("processingResponse"),
            SessionError.sequencingViolation("unexpected data"),
            SessionError.policyViolation(reason: "privacyPolicyURLInvalid"),
            SessionError.invalidDeviceRequest,
            SessionError.protocolError,
            SessionError.peerTermination
        ]
    )
    func otherErrorsMapToLegacyCarryingTheOriginalError(error: SessionError) {
        #expect(FailureCategory(error) == .legacy(error))
    }

    @Test("transportError maps to the bluetoothConnection category carrying the error")
    func transportErrorMapsToBluetoothConnection() {
        #expect(FailureCategory(.transportError) == .bluetoothConnection(.transportError))
    }

    // MARK: - HolderSessionState.failed(_:)

    @Test("failed(_:) builds a presentation with the mapped category and the error description")
    func failedHelperBuildsPresentation() {
        let state = HolderSessionState.failed(.generic("Credential signing failed"))

        #expect(
            state == .failed(
                presentation: ResolutionPresentation(
                    result: .failed(.generic, errorDescription: "Credential signing failed")
                )
            )
        )
    }

    @Test("failed(_:) for a legacy error carries the error and its description for analytics")
    func failedHelperForLegacyErrorCarriesError() {
        let error = SessionError.peerTermination

        #expect(
            HolderSessionState.failed(error) == .failed(
                presentation: ResolutionPresentation(
                    result: .failed(.legacy(error), errorDescription: error.errorDescription ?? "")
                )
            )
        )
    }

    @Test("failed(_:) uses the SessionError.errorDescription as the description")
    func failedHelperUsesErrorDescription() {
        let state = HolderSessionState.failed(.unknown)

        guard case .failed(let presentation) = state,
              case .failed(_, let description)? = presentation.result else {
            Issue.record("Expected a failed presentation")
            return
        }
        #expect(description == SessionError.unknown.errorDescription)
    }

    @Test("failed(_:) produces a state of kind .failed")
    func failedHelperHasFailedKind() {
        #expect(HolderSessionState.failed(.peerTermination).kind == .failed)
    }
}
