@testable import mobile_credential_sharing_ios
import Testing
internal import UIKit

struct QRCodeViewControllerTests {

    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() async throws {
        let sut = await QRCodeViewController()
        await sut.viewDidLoad()
        
        await #expect(sut.view.subviews.count == 1)
    }

}
