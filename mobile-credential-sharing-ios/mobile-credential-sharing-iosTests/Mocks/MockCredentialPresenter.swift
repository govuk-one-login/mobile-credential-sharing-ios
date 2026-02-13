import CredentialSharingUI
import XCTest

class MockCredentialPresenter: CredentialPresenting {
    var presentCredentialCalled = false
    var presentedData: Data?
    var presentedViewController: UIViewController?
    
    func presentCredential(
        _ data: Data,
        over viewController: UIViewController
    ) {
        presentCredentialCalled = true
        presentedData = data
        presentedViewController = viewController
    }
}
