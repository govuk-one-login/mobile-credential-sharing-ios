import CredentialSharingTestFixtures
import DesignSystem
@testable import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("EngagementViewModel Tests")
struct QRCodeViewModelTests {
    private let mockOrchestrator = MockHolderOrchestrator()
    private let analyticsService = MockSharingAnalyticsService()

    private func makeQRView(payload: String? = "mdoc-payload") throws -> QRCodeView {
        let image = try payload.map { try QRGenerator.generateQRCode(from: $0) }
        return QRCodeView(image: image)
    }

    private func makeSUT(
        qrPayload: String? = "mdoc-payload",
        cancelRequiresConfirmation: Bool? = false,
        qrCodeView: QRCodeView? = nil
    ) throws -> EngagementViewModel {
        EngagementViewModel(
            presentation: EngagementPresentation(
                qrPayload: qrPayload,
                cancelRequiresConfirmation: cancelRequiresConfirmation
            ),
            orchestrator: mockOrchestrator,
            qrCodeView: try qrCodeView ?? makeQRView(payload: qrPayload),
            analyticsService: analyticsService,
            onCancel: { [mockOrchestrator] in mockOrchestrator.userDidTapCancel() }
        )
    }

    // MARK: - Body composition

    @Test("Body is ordered title, QR view, then 3x body copy")
    func bodyOrderMatchesDesign() throws {
        let qrView = try makeQRView()
        let sut = try makeSUT(qrCodeView: qrView)

        #expect(sut.body.count == 5)

        let title = try #require(sut.body[0] as? GDSTextViewModel)
        #expect(title.accessibilityIdentifier == "qr-code-title")
        #expect(title.accessibilityTraits == .header)

        // The QR slot is the controller-owned live view, inserted via a passthrough so
        // GDSScreen does not freeze a copy of it.
        let qrSlot = try #require(sut.body[1] as? PassthroughContentViewModel)
        #expect(qrSlot.createUIView() === qrView)

        let body1 = try #require(sut.body[2] as? GDSTextViewModel)
        let body2 = try #require(sut.body[3] as? GDSTextViewModel)
        let body3 = try #require(sut.body[4] as? GDSTextViewModel)
        #expect(body1.accessibilityIdentifier == "qr-code-body-1")
        #expect(body2.accessibilityIdentifier == "qr-code-body-2")
        #expect(body3.accessibilityIdentifier == "qr-code-body-3")
    }

    @Test("Exposed title, body and QR view match what is used in the body")
    func exposedContentMatchesBody() throws {
        let qrView = try makeQRView()
        let sut = try makeSUT(qrCodeView: qrView)

        #expect(sut.titleContent.accessibilityIdentifier == "qr-code-title")
        #expect(sut.bodyContent[0].accessibilityIdentifier == "qr-code-body-1")
        #expect(sut.bodyContent[1].accessibilityIdentifier == "qr-code-body-2")
        #expect(sut.bodyContent[2].accessibilityIdentifier == "qr-code-body-3")
        #expect(sut.qrCodeView === qrView)
    }

    @Test("Uses the top screen style and hides the back button")
    func screenConfiguration() throws {
        let sut = try makeSUT()
        #expect(sut.backButtonIsHidden)
        #expect(sut.movableFooter.isEmpty)
        #expect(sut.footer.isEmpty)
    }

    // MARK: - Cancel bar button (Interaction AC1)

    @Test("Cancel bar button is present when cancel confirmation is specified")
    func cancelButtonPresentWhenConfirmationSpecified() throws {
        let sut = try makeSUT(cancelRequiresConfirmation: false)

        let barButton = try #require(sut.rightBarButtons?.first)
        #expect(barButton.accessibilityIdentifier == "right-bar-button")
        guard case let .button(title, _, _) = barButton.content else {
            Issue.record("Expected a .button content for the cancel bar button")
            return
        }
        #expect(title == GDSLocalisedString(stringKey: "cancel", bundle: .module).value)
    }

    @Test("No cancel bar button when cancel confirmation is nil")
    func noCancelButtonWhenConfirmationNil() throws {
        let sut = try makeSUT(cancelRequiresConfirmation: nil)
        #expect(sut.rightBarButtons == nil)
    }

    @Test("Cancel bar button routes to onCancel and tracks the cancel event (Analytics AC2)")
    func cancelRoutesAndTracksEvent() throws {
        let sut = try makeSUT()

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
        let sut = try makeSUT()

        #expect(analyticsService.trackedScreens.isEmpty)

        if case let .action(action) = sut.didAppear {
            action()
        } else {
            Issue.record("Expected a synchronous .action for didAppear")
        }

        #expect(analyticsService.trackedScreens == [.qrCode])
    }
}
