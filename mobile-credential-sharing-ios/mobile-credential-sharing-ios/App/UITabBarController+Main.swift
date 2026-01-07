import UIKit

extension UITabBarController {
    static func makeMain() -> UITabBarController {
        // Create instances of view controllers and navigation controllers
        let holderVC = HolderViewController()
        let verifierVC = VerifierViewController()

        let holderNavController = UINavigationController(rootViewController: holderVC)
        holderNavController.navigationBar.prefersLargeTitles = true
        let verifierNavController = UINavigationController(rootViewController: verifierVC)
        verifierNavController.navigationBar.prefersLargeTitles = true
        
        // Enable state restoration for navigation controllers
        holderNavController.restorationIdentifier = "HolderNavController"
        verifierNavController.restorationIdentifier = "VerifierNavController"
                
        // Configure tab bar items
        holderNavController.tabBarItem = UITabBarItem(title: "Holder", image: UIImage(systemName: "person.text.rectangle"), tag: 0)
        verifierNavController.tabBarItem = UITabBarItem(title: "Verifier", image: UIImage(systemName: "qrcode.viewfinder"), tag: 1)
                
        // Create the Tab Bar Controller and set view controllers
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [holderNavController, verifierNavController]
                
        // Enable state restoration for the tab bar controller
        tabBarController.restorationIdentifier = "MainTabBarController"
        
        return tabBarController
    }
}
