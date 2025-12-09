@testable import mobile_credential_sharing_ios
import Testing
internal import UIKit


@MainActor
@Suite("HolderViewControllerTests")
struct HolderViewControllerTests {
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = HolderViewController()
        sut.viewDidLoad()
        
        #expect(sut.view.subviews.count == 4)
    }

    @Test("Tapping button sucessfully loads QRCodeViewController")
    func tapOnButtonLoadsQRCodeViewController() {
        let sut = HolderViewController()
        let navigationController = UINavigationController(
            rootViewController: sut
        )
        
        sut.navigateToQRCodeView()
        #expect(sut.view.subviews.count == 3)
    }
}
