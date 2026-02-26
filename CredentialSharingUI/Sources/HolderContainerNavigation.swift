import UIKit

public class HolderContainerNavigation: UINavigationController {
    public var viewPresented: Bool = false
    var holderContainer: HolderContainer
    
    init(holderContainer: HolderContainer) {
        self.holderContainer = holderContainer
        super.init(rootViewController: holderContainer)
    }
    
    public convenience init() {
        self.init(holderContainer: HolderContainer())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        // Each time a new presentation is started, the presentationController delegate must be set
        self.presentationController?.delegate = self
    }
}

// MARK: - Presentation Controller Delegate
extension HolderContainerNavigation: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.holderContainer.didTapCancel()
    }
}
