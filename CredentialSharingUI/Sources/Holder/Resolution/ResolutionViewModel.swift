import DesignSystem
import SharingLogging
import SharingOrchestration
import UIKit

@MainActor
struct ResolutionViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel]
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action? = nil
    let didDismiss: DesignSystem.Action? = nil
    
    private let orchestrator: HolderOrchestratorProtocol

    init(
        orchestrator: HolderOrchestratorProtocol,
        message: String
    ) {
        self.orchestrator = orchestrator
        self.body = [
            GDSTextViewModel(
                title: GDSLocalisedString(stringLiteral: message),
                titleFont: DesignSystem.Font.Base.title2,
                alignment: .center,
                accessibilityTraits: .header,
                accessibilityIdentifier: "ResolutionStateLabel",
                verticalPadding: .vertical(DesignSystem.Spacing.default)
            )
        ]
        self.movableFooter = [Self.makeGoBackButton(
            orchestrator: orchestrator
        )]
    }
    
    private static func makeGoBackButton(
        orchestrator: HolderOrchestratorProtocol
    ) -> GDSButtonViewModel {
        GDSButtonViewModel(
            title: GDSLocalisedString(stringKey: "goBackToDocumentsButton", bundle: .module).value,
            style: .primary,
            buttonAction: .action {
                orchestrator.userDidFinish()
            },
            accessibilityIdentifier: "go-back-to-documents-button",
            horizontalPadding: .horizontal(DesignSystem.Spacing.default)
        )
    }
}
