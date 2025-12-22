@testable import mobile_credential_sharing_ios
import Testing
internal import UIKit


@MainActor
@Suite("HomePageViewControllerTests")
struct HomePageViewControllerTests {
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = HomePageViewController()
        sut.viewDidLoad()
        
        #expect(sut.view.subviews.count == 5)
    }

    @Test("Tapping button sucessfully loads QRCodeViewController")
    func tapOnButtonLoadsQRCodeViewController() {
        let sut = HomePageViewController()
        _ = UINavigationController(rootViewController: sut)
        
        sut.navigateToQRCodeView()
        #expect(sut.view.subviews.count == 4)
    }
}
