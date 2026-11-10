import CredentialSharingTestFixtures
import DesignSystem
@testable import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("QRCodeViewModel Tests")
struct QRCodeViewModelTests {
    private let mockOrchestrator = MockHolderOrchestrator()
    private let analyticsService = MockSharingAnalyticsService()

    private func makeSUT(
        qrPayload: String? = "mdoc-payload",
        cancelRequiresConfirmation: Bool? = false
    ) -> QRCodeViewModel {
        QRCodeViewModel(
            presentation: EngagementPresentation(
                qrPayload: qrPayload,
                cancelRequiresConfirmation: cancelRequiresConfirmation
            ),
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    // MARK: - Body composition

    @Test("Body is ordered title, QR code, then body copy")
    func bodyOrderMatchesDesign() throws {
        let sut = makeSUT()

        #expect(sut.body.count == 3)

        let title = try #require(sut.body[0] as? GDSTextViewModel)
        #expect(title.accessibilityIdentifier == "qr-code-title")
        #expect(title.accessibilityTraits == .header)

        let qr = try #require(sut.body[1] as? GDSImageViewModel)
        #expect(qr.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier)

        let body = try #require(sut.body[2] as? GDSTextViewModel)
        #expect(body.accessibilityIdentifier == "qr-code-body")
    }

    @Test("Exposed title and body content match the content used in the body")
    func exposedContentMatchesBody() throws {
        let sut = makeSUT()

        #expect(sut.titleContent.accessibilityIdentifier == "qr-code-title")
        #expect(sut.bodyContent.accessibilityIdentifier == "qr-code-body")
        #expect(sut.qrContent.count == 1)
        let qr = try #require(sut.qrContent.first as? GDSImageViewModel)
        #expect(qr.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier)
    }

    @Test("Uses the top screen style and hides the back button")
    func screenConfiguration() {
        let sut = makeSUT()
        #expect(sut.backButtonIsHidden)
        #expect(sut.movableFooter.isEmpty)
        #expect(sut.footer.isEmpty)
    }

    // MARK: - QR content fallback

    @Test("A nil payload renders blank space in a square slot and does not report a failure")
    func nilPayloadShowsBlankSquareSlot() throws {
        let sut = makeSUT(qrPayload: nil)

        #expect(sut.body.count == 3)
        // The empty state is blank space wrapped in a square slot so the body copy below
        // keeps its position (matching the footprint the natural QR image would occupy).
        let slot = try #require(sut.body[1] as? SquareSlotContentViewModel)
        #expect(slot.accessibilityIdentifier == "qr-code-slot")
        #expect(slot.wrapped is BlankContentViewModel)
        #expect(mockOrchestrator.qrCodeGenerationDidFailCalled == false)
    }

    @Test("The QR image is placed directly in the body without a square-slot wrapper")
    func qrImageIsNotWrapped() throws {
        let sut = makeSUT()

        // The QR image keeps its natural, width-driven size, so it is not wrapped.
        let qr = try #require(sut.body[1] as? GDSImageViewModel)
        #expect(qr.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier)
    }

    @Test("makeLandscapeQRContent returns the QR image when a payload is present")
    func landscapeQRContentMatchesPortrait() throws {
        let sut = makeSUT()

        let landscapeQR = try #require(sut.makeLandscapeQRContent().first as? GDSImageViewModel)
        #expect(landscapeQR.accessibilityIdentifier == QRCodeViewModel.qrImageAccessibilityIdentifier)
    }

    @Test("makeLandscapeQRContent is empty when the payload is nil")
    func landscapeQRContentNilPayload() {
        let sut = makeSUT(qrPayload: nil)

        #expect(sut.makeLandscapeQRContent().isEmpty)
    }

    // MARK: - Cancel bar button (Interaction AC1)

    @Test("Cancel bar button is present when cancel confirmation is specified")
    func cancelButtonPresentWhenConfirmationSpecified() throws {
        let sut = makeSUT(cancelRequiresConfirmation: false)

        let barButton = try #require(sut.rightBarButtons?.first)
        #expect(barButton.accessibilityIdentifier == "right-bar-button")
        guard case let .button(title, _, _) = barButton.content else {
            Issue.record("Expected a .button content for the cancel bar button")
            return
        }
        #expect(title == GDSLocalisedString(stringKey: "cancel", bundle: .module).value)
    }

    @Test("No cancel bar button when cancel confirmation is nil")
    func noCancelButtonWhenConfirmationNil() {
        let sut = makeSUT(cancelRequiresConfirmation: nil)
        #expect(sut.rightBarButtons == nil)
    }

    @Test("Cancel bar button routes to onCancel and tracks the cancel event (Analytics AC2)")
    func cancelRoutesAndTracksEvent() throws {
        let sut = makeSUT()

        #expect(analyticsService.trackedEvents.isEmpty)
        #expect(mockOrchestrator.cancelPresentationCalled == false)

        let barButton = try #require(sut.rightBarButtons?.first)
        let action = try #require(barButton.action)
        action()

        #expect(mockOrchestrator.cancelPresentationCalled)
        #expect(analyticsService.trackedEvents == [.cancel])
    }

    // MARK: - Analytics (Analytics AC1)

    @Test("didAppear logs the QR code screen view")
    func didAppearTracksScreenView() throws {
        let sut = makeSUT()

        #expect(analyticsService.trackedScreens.isEmpty)

        if case let .action(action) = sut.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.trackedScreens == [.qrCode])
    }
}
