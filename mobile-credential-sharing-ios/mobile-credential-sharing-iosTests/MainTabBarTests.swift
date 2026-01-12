import HolderUI
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
    
    @Test("AC2: Verifier tab shows placeholder content")
    func verifierTabContent() throws {
        let tabBar = makeSUT()
        
        guard let nav = tabBar.viewControllers?[1] as? UINavigationController,
              let verifierVC = nav.viewControllers.first as? VerifierViewController else {
            Issue.record("Verifier setup is incorrect")
            return
        }
        
        verifierVC.loadViewIfNeeded()
        
        // Assert using accessibility identifiers
        let scanButton = verifierVC.view.subviews.first {
            $0.accessibilityIdentifier == VerifierViewController.scanButtonIdentifier
        }
        let foundButton = try #require(scanButton as? UIButton)
        
        #expect(foundButton.title(for: .normal) == "Scan Credential")
        #expect(foundButton.isHidden == false)
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
