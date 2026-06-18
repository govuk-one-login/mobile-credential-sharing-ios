import Testing
internal import UIKit

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("MainTabBarTests")
struct MainTabBarTests {

    // Helper to create the app view hierarchy
    func makeSUT() -> UITabBarController {
        let tabBar = UITabBarController.makeMain()
        
        // ensure the SUT is in the state the user would see immediately after launch
        if let nav = tabBar.selectedViewController as? UINavigationController {
            nav.viewControllers.first?.loadViewIfNeeded()
        }
        
        return tabBar
    }
    
    @Test("AC1: App opens to Holder tab")
    func initialLaunchState() {
        let tabBar = makeSUT()
    
        let nav = tabBar.selectedViewController as? UINavigationController
        let holderVC = nav?.viewControllers.first
        
        #expect(tabBar.selectedIndex == 0)
        #expect(holderVC is HolderViewController)
        #expect(holderVC?.title == "Holder")
    }
    
    @Test("AC2: Verifier tab shows selection UI")
    func verifierTabContent() throws {
        let tabBar = makeSUT()
        
        guard let nav = tabBar.viewControllers?[1] as? UINavigationController,
              let verifierVC = nav.viewControllers.first as? VerifierViewController else {
            Issue.record("Verifier setup is incorrect")
            return
        }
        
        verifierVC.loadViewIfNeeded()
        
        let option1 = try #require(findButton(in: verifierVC.view, identifier: VerifierViewController.option1Identifier))
        let option2 = try #require(findButton(in: verifierVC.view, identifier: VerifierViewController.option2Identifier))
        let verifyButton = try #require(findButton(in: verifierVC.view, identifier: VerifierViewController.verifyCredentialIdentifier))
        
        #expect(option1.title(for: .normal) == "Photo and Age Over 21")
        #expect(option2.title(for: .normal) == "Name + Title (Retain) and Age Over 23")
        #expect(verifyButton.title(for: .normal) == "Verify Credential")
    }
    
    private func findButton(in view: UIView, identifier: String) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityIdentifier == identifier {
            return button
        }
        for subview in view.subviews {
            if let found = findButton(in: subview, identifier: identifier) {
                return found
            }
        }
        return nil
    }
    
    @Test("AC3: Switching tabs updates content")
    func tabSwitching() {
        let tabBar = makeSUT()
        
        // Switch to Verifier (index 1)
        tabBar.selectedIndex = 1
        let selectedNav = tabBar.selectedViewController as? UINavigationController
        #expect(selectedNav?.viewControllers.first is VerifierViewController)
        
        // Switch to Verifier (index 0)
        tabBar.selectedIndex = 0
        let newSelectedNav = tabBar.selectedViewController as? UINavigationController
        #expect(newSelectedNav?.viewControllers.first is HolderViewController)
    }
}
