import UIKit

public class VerifierContainerNavigation: UINavigationController {
    var verifierContainer: VerifierContainer

    init(verifierContainer: VerifierContainer) {
        self.verifierContainer = verifierContainer
        super.init(rootViewController: verifierContainer)
    }

    public convenience init() {
        self.init(verifierContainer: VerifierContainer())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.presentationController?.delegate = self
    }
}

extension VerifierContainerNavigation: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.verifierContainer.orchestrator.cancelVerification()
        self.popToRootViewController(animated: false)
    }
}
