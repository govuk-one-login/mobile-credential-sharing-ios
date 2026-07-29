import UIKit

class HolderContainerNavigation: UINavigationController {
    var holderContainer: HolderContainer
    
    init(holderContainer: HolderContainer) {
        self.holderContainer = holderContainer
        super.init(rootViewController: holderContainer)
        self.delegate = self
        self.isModalInPresentation = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // Each time a new presentation is started, the presentationController delegate must be set
        self.presentationController?.delegate = self
    }
}

// MARK: - UINavigationControllerDelegate
extension HolderContainerNavigation: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard viewController !== holderContainer else { return }
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        viewController.navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "CancelButton"
    }

    @objc private func cancelButtonTapped() {
        holderContainer.didTapCancel()
    }
}

// MARK: - Presentation Controller Delegate
extension HolderContainerNavigation: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        holderContainer.didTapCancel()
    }
}
