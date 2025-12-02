@testable import mobile_credential_sharing_ios
import Testing
internal import UIKit

@MainActor
@Suite("QRCodeViewControllerTests")
struct QRCodeViewControllerTests {

    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = QRCodeViewController()
        sut.viewDidLoad()
        
        #expect(sut.view.subviews.count == 1)
    }

}
