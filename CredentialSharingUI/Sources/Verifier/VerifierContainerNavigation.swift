import SharingOrchestration
import UIKit

public class VerifierContainerNavigation: UINavigationController {
    var verifierContainer: VerifierContainer

    init(verifierContainer: VerifierContainer) {
        self.verifierContainer = verifierContainer
        super.init(rootViewController: verifierContainer)
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
        self.delegate = self
        self.presentationController?.delegate = self
    }
}

extension VerifierContainerNavigation: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.verifierContainer.orchestrator.cancelVerification()
        self.popToRootViewController(animated: false)
    }
}

extension VerifierContainerNavigation: UINavigationControllerDelegate {
    public func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        viewController.navigationItem.hidesBackButton = true
    }
}
