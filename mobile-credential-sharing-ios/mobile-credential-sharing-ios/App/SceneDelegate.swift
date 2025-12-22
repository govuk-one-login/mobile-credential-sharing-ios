import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)

        // Create instances of view controllers and navigation controllers
        let holderVC = HolderViewController()
        let verifierVC = VerifierViewController()

        let holderNavController = UINavigationController(rootViewController: holderVC)
        let verifierNavController = UINavigationController(rootViewController: verifierVC)
        
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

        // Set the window's root view controller and make key and visible
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
