import CredentialSharingTestFixtures
import DesignSystem
@testable import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("EngagementViewController Tests")
struct EngagementViewControllerTests {
    private let mockOrchestrator = MockHolderOrchestrator()
    private let analyticsService = MockSharingAnalyticsService()

    private func makeSUT(
        qrPayload: String? = "mdoc-payload",
        cancelRequiresConfirmation: Bool? = false,
        onCancel: @escaping () -> Void = {}
    ) throws -> EngagementViewController {
        try EngagementViewController(
            presentation: EngagementPresentation(
                qrPayload: qrPayload,
                cancelRequiresConfirmation: cancelRequiresConfirmation
            ),
            orchestrator: mockOrchestrator,
            analyticsService: analyticsService,
            onCancel: onCancel
        )
    }

    /// Loads the view, sizes it, and runs a layout pass so the orientation decision in
    /// `viewWillLayoutSubviews` is applied.
    private func layout(_ sut: EngagementViewController, landscape: Bool) {
        sut.loadViewIfNeeded()
        sut.view.frame = landscape
            ? CGRect(x: 0, y: 0, width: 800, height: 400)
            : CGRect(x: 0, y: 0, width: 400, height: 800)
        sut.view.setNeedsLayout()
        sut.view.layoutIfNeeded()
    }

    // MARK: - Portrait

    @Test("Portrait shows the GDS single-column content and hides the landscape view")
    func portraitShowsGDSContent() throws {
        let sut = try makeSUT()

        layout(sut, landscape: false)

        let landscapeView = try #require(sut.view.firstSubview(ofType: QRCodeLandscapeView.self))
        let gdsContent = try #require(
            sut.view.findView(with: "gds-screen-container-stack-view")
        )

        #expect(landscapeView.isHidden)
        #expect(gdsContent.isHidden == false)
    }

    // MARK: - Landscape

    @Test("Landscape shows the two-column landscape view and hides the GDS content")
    func landscapeShowsLandscapeView() throws {
        let sut = try makeSUT()

        layout(sut, landscape: true)

        let landscapeView = try #require(sut.view.firstSubview(ofType: QRCodeLandscapeView.self))
        let gdsContent = try #require(
            sut.view.findView(with: "gds-screen-container-stack-view")
        )

        #expect(landscapeView.isHidden == false)
        #expect(gdsContent.isHidden)
    }

    // MARK: - Rotation

    @Test("Rotating landscape → portrait restores the GDS content and hides the landscape view")
    func rotatingBackToPortraitRestoresGDSContent() throws {
        let sut = try makeSUT()

        layout(sut, landscape: true)
        layout(sut, landscape: false)

        let landscapeView = try #require(sut.view.firstSubview(ofType: QRCodeLandscapeView.self))
        let gdsContent = try #require(
            sut.view.findView(with: "gds-screen-container-stack-view")
        )

        #expect(landscapeView.isHidden)
        #expect(gdsContent.isHidden == false)
    }

    // MARK: - Shared wiring

    @Test("Back button is hidden")
    func backButtonHidden() throws {
        let sut = try makeSUT()
        sut.viewWillAppear(false)
        #expect(sut.navigationItem.hidesBackButton)
    }

    @Test("Cancel bar button is installed when cancel confirmation is specified")
    func cancelButtonInstalled() throws {
        let sut = try makeSUT()
        sut.viewWillAppear(false)

        let barButton = try #require(sut.navigationItem.rightBarButtonItem)
        #expect(barButton.accessibilityIdentifier == "right-bar-button")
    }

    @Test("No cancel bar button when cancel confirmation is nil")
    func noCancelButtonWhenConfirmationNil() throws {
        let sut = try makeSUT(cancelRequiresConfirmation: nil)
        sut.viewWillAppear(false)
        #expect(sut.navigationItem.rightBarButtonItem == nil)
    }

    @Test("didAppear tracks the QR code screen view")
    func didAppearTracksScreenView() throws {
        let sut = try makeSUT()
        sut.loadViewIfNeeded()

        #expect(analyticsService.trackedScreens.isEmpty)

        sut.viewDidAppear(false)

        #expect(analyticsService.trackedScreens == [.qrCode])
    }

    // MARK: - Refresh (QR expiry / hide)

    @Test("refresh updates the QR in place in both the portrait and landscape views")
    func refreshUpdatesBothQRViews() throws {
        // Start hidden so both QR views begin blank.
        let sut = try makeSUT(qrPayload: nil)
        sut.loadViewIfNeeded()

        let qrImages = sut.view.allSubviews(ofType: UIImageView.self).filter {
            $0.accessibilityIdentifier == EngagementViewModel.qrImageAccessibilityIdentifier
        }
        // Portrait + landscape QR views each own an image view.
        #expect(qrImages.count == 2)
        #expect(qrImages.allSatisfy { $0.isHidden })

        // A fresh payload (expiry refresh) shows the QR in both.
        try sut.refresh(with: EngagementPresentation(qrPayload: "fresh-payload", cancelRequiresConfirmation: false))
        #expect(qrImages.allSatisfy { !$0.isHidden && $0.image != nil })

        // A nil payload (hide/grace window) blanks both again.
        try sut.refresh(with: EngagementPresentation(qrPayload: nil, cancelRequiresConfirmation: false))
        #expect(qrImages.allSatisfy { $0.isHidden })
    }
}

// MARK: - Test helpers

private extension UIView {
    func findView(with accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier {
            return self
        }
        for subview in subviews {
            if let found = subview.findView(with: accessibilityIdentifier) {
                return found
            }
        }
        return nil
    }

    func firstSubview<T: UIView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for subview in subviews {
            if let found = subview.firstSubview(ofType: type) {
                return found
            }
        }
        return nil
    }

    func allSubviews<T: UIView>(ofType type: T.Type) -> [T] {
        var result: [T] = []
        for subview in subviews {
            if let match = subview as? T {
                result.append(match)
            }
            result.append(contentsOf: subview.allSubviews(ofType: type))
        }
        return result
    }
}
