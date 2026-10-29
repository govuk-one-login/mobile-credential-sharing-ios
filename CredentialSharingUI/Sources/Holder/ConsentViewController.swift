import DesignSystem
import GDSAnalytics
import Logging
import SharingLogging
import SharingOrchestration
import SharingPrerequisiteGate
import UIKit

@MainActor
final class ConsentViewController: GDSScreen {
    private let orchestrator: HolderOrchestratorProtocol

    init(presentation: ConsentPresentation,
         orchestrator: HolderOrchestratorProtocol,
         container: HolderContainerProtocol,
         analyticsService: AnalyticsService? = nil
    ) {
        self.orchestrator = orchestrator
        // `container` is currently unused but kept to match the HolderContainer call
        // cancel/dismiss wiring lands in DCMAW-23709 and readAbout in DCMAW-23711
        super.init(
            viewModel: ConsentViewModel(
                presentation: presentation,
                onAgree: { orchestrator.userDidTapApprove() },
                onReadAbout: {},
                onCancel: {},
                analyticsService: analyticsService
            )
        )
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

private final class PreviewOrchestrator: HolderOrchestratorProtocol {
    weak var delegate: (any HolderOrchestratorDelegate)?
    func startPresentation() {}
    func resolve(_ missingPrerequisite: MissingPrerequisite) {}
    func userDidTapApprove() {}
    func userDidTapDeny() {}
    func userDidTapCancel() {}
    func userDidConfirmCancel() {}
}

private final class PreviewContainer: HolderContainerProtocol {
    weak var delegate: HolderContainerDelegate?
}

private struct ConsentViewControllerPreview: UIViewControllerRepresentable {
    let attributes: [ConsentAttribute]

    func makeUIViewController(context: Context) -> UIViewController {
        let presentation = ConsentPresentation(
            dvsName: "Yoti Ltd.",
            documentType: DocumentType(displayLabel: "Driving Licence", documentIcon: UIImage()),
            attributes: attributes,
            privacyPolicyURL: URL(string: "https://example.com/privacy")!
        )
        let viewController = ConsentViewController(
            presentation: presentation,
            orchestrator: PreviewOrchestrator(),
            container: PreviewContainer()
        )
        return UINavigationController(rootViewController: viewController)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Uses `PreviewProvider` + `UIViewControllerRepresentable` rather than the
// `#Preview` macro: against this SDK the macro resolves to the iOS 17+
// `Preview(_:traits:body:)` overload, but this package targets iOS 16.
struct ConsentViewController_Previews: PreviewProvider {
    static var previews: some View {
        // Variant: some details kept
        ConsentViewControllerPreview(attributes: [
            ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Name", intentToRetain: true),
            ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Photo", intentToRetain: false)
        ])
        .previewDisplayName("Some details kept")

        // Variant: no details kept
        ConsentViewControllerPreview(attributes: [
            ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Photo", intentToRetain: false)
        ])
        .previewDisplayName("No details kept")

        // Variant: all details kept
        ConsentViewControllerPreview(attributes: [
            ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: "Name", intentToRetain: true)
        ])
        .previewDisplayName("All details kept")
    }
}

#endif
