import DesignSystem
import Logging
import SharingLogging
import SharingOrchestration
import UIKit

// MARK: - TerminalStateMessageViewModel

@MainActor
struct TerminalStateMessageViewModel: GDSScreenViewModel, BaseViewModel {
    let screenStyle: GDSScreenStyle = .centred
    let body: [any ContentViewModel]
    let movableFooter: [any ContentViewModel] = []
    let footer: [any ContentViewModel] = []
    let rightBarButtonTitle: GDSLocalisedString? = nil
    let backButtonTitle: GDSLocalisedString? = nil
    let backButtonIsHidden: Bool = true
    let didAppear: DesignSystem.Action? = nil
    let didDismiss: DesignSystem.Action? = nil

    init(message: String) {
        self.body = [
            GDSTextViewModel(
                title: GDSLocalisedString(stringLiteral: message),
                titleFont: DesignSystem.Font.Base.title2,
                alignment: .center,
                accessibilityTraits: .header,
                accessibilityIdentifier: "TerminalStateLabel",
                verticalPadding: .vertical(DesignSystem.Spacing.default)
            )
        ]
    }
}
