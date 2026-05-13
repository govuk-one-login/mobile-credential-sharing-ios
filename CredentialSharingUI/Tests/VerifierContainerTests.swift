import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
struct VerifierContainerTests {
    let mockOrchestrator = MockVerifierOrchestrator()

    @Test("viewWillAppear calls startVerification on orchestrator")
    func viewWillAppearCallsStart() {
        let sut = VerifierContainer(orchestrator: mockOrchestrator)
        #expect(mockOrchestrator.startVerificationCalled == false)

        sut.viewWillAppear(false)

        #expect(mockOrchestrator.startVerificationCalled == true)
    }

    @Test("presentationControllerDidDismiss calls cancelVerification on orchestrator")
    func dismissCallsCancel() throws {
        let container = VerifierContainer(orchestrator: mockOrchestrator)
        let sut = VerifierContainerNavigation(verifierContainer: container)
        #expect(mockOrchestrator.cancelVerificationCalled == false)

        sut.presentationControllerDidDismiss(try #require(sut.presentationController))

        #expect(mockOrchestrator.cancelVerificationCalled == true)
    }
}
