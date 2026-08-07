import SharingCryptoService
import SharingOrchestration
import UIKit

public class VerifierContainerNavigation: UINavigationController {
    var verifierContainer: VerifierContainer

    init(verifierContainer: VerifierContainer) {
        self.verifierContainer = verifierContainer
        super.init(rootViewController: verifierContainer)
        self.delegate = self
        self.isModalInPresentation = true
    }

    public convenience init(attributeGroup: AttributeGroup) {
        self.init(
            verifierContainer: VerifierContainer(attributeGroup: attributeGroup)
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.presentationController?.delegate = self
    }
}

extension VerifierContainerNavigation: UINavigationControllerDelegate {
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        viewController.navigationItem.hidesBackButton = true
        guard viewController !== verifierContainer else { return }

        if viewController is AttributeResultViewController || viewController is ErrorViewController {
            isModalInPresentation = false
            return
        }

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
        verifierContainer.didTapCancel()
    }
}

// MARK: - Presentation Controller Delegate
extension VerifierContainerNavigation: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        verifierContainer.didTapCancel()
    }
}
