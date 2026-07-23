import UIKit

class HolderContainerNavigation: UINavigationController {
    var viewPresented: Bool = false
    var holderContainer: HolderContainer
    
    init(holderContainer: HolderContainer) {
        self.holderContainer = holderContainer
        super.init(rootViewController: holderContainer)
        self.delegate = self
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
            title: "Done",
            style: .plain,
            target: self,
            action: #selector(doneButtonTapped)
        )
        viewController.navigationItem.rightBarButtonItem?.tintColor = .systemBlue
        viewController.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "DoneButton"
    }

    @objc private func doneButtonTapped() {
        holderContainer.didTapCancel()
        dismiss(animated: true)
    }
}

// MARK: - Presentation Controller Delegate
extension HolderContainerNavigation: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.holderContainer.didTapCancel()
        self.popToRootViewController(animated: false)
    }
}
