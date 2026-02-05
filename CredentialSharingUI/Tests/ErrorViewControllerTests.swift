import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ErrorViewController Tests")
struct ErrorViewControllerTests {
    @Test("Checking the view loads successfully")
    func checkSubviewLoadsCorrectly() {
        let sut = ErrorViewController(titleText: "Test title")
        sut.viewDidLoad()

        #expect(sut.view.subviews.count == 2)
        #expect(
            sut.view.subviews.contains(where: {
                $0 is UILabel && ($0 as? UILabel)?.text == "Test title"
            })
        )
    }
}
