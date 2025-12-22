import UIKit
import HolderUI

@MainActor
public protocol CredentialPresenting {
    func presentCredential(_ data: Data, over viewController: UIViewController)
}

extension CredentialPresenter: CredentialPresenting {}

public class MockCredentialPresenter: CredentialPresenting {
    var presentCredentialCalled = false
    var presentedData: Data?
    var presentedViewController: UIViewController?

    public init() {}
    
    public func presentCredential(
        _ data: Data,
        over viewController: UIViewController
    ) {
        presentCredentialCalled = true
        presentedData = data
        presentedViewController = viewController
    }
}
