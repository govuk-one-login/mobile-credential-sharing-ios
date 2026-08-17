import CredentialSharingUI
import Testing
internal import UIKit

@testable import mobile_credential_sharing_ios

@MainActor
@Suite("HolderViewControllerTests")
struct HolderViewControllerTests {

    // MARK: Display List of Mock Credentials
    @Test("Displays table view with correct number of credential rows")
    func displaysCredentialList() {
        // Given
        let sut = HolderViewController()

        // When
        _ = sut.view

        // Then
        #expect(sut.title == "Holder")
        #expect(sut.tableView.numberOfRows(inSection: 0) == MockCredential.allMocks.count)
    }

    @Test("Each cell displays the credential displayName")
    func cellsShowDisplayName() {
        // Given
        let sut = HolderViewController()
        _ = sut.view

        // When
        let indexPath = IndexPath(row: 0, section: 0)
        let cell = sut.tableView.dataSource?.tableView(sut.tableView, cellForRowAt: indexPath)

        // Then
        #expect(cell?.textLabel?.text == MockCredential.allMocks[0].displayName)
    }

    @Test("Signing failure credential is displayed in the list")
    func signingFailureCredentialDisplayed() {
        // Given
        let sut = HolderViewController()
        _ = sut.view

        // When
        let allCellTexts = (0..<sut.tableView.numberOfRows(inSection: 0)).compactMap { row in
            let indexPath = IndexPath(row: row, section: 0)
            let cell = sut.tableView.dataSource?.tableView(sut.tableView, cellForRowAt: indexPath)
            return cell?.textLabel?.text
        }

        // Then
        #expect(allCellTexts.contains("Jane Doe (Signing Failure)"))
    }

    @Test("Authentication cancelled once credential is displayed in the list")
    func authCancelledOnceCredentialDisplayed() {
        // Given
        let sut = HolderViewController()
        _ = sut.view

        // When
        let allCellTexts = (0..<sut.tableView.numberOfRows(inSection: 0)).compactMap { row in
            let indexPath = IndexPath(row: row, section: 0)
            let cell = sut.tableView.dataSource?.tableView(sut.tableView, cellForRowAt: indexPath)
            return cell?.textLabel?.text
        }

        // Then
        #expect(allCellTexts.contains("Jane Doe (Authentication Cancelled Once)"))
    }

    @Test("Old Present Credential button is no longer present")
    func oldButtonRemoved() {
        // Given
        let sut = HolderViewController()

        // When
        _ = sut.view

        // Then
        let button = sut.view.subviews.first { $0 is UIButton }
        #expect(button == nil)
    }

    // MARK: Selection Initiates Sharing Flow
    @Test("Tapping a credential row presents the sharing journey")
    func selectionPresentsJourney() async throws {
        // Given
        let window = UIWindow(frame: UIScreen.main.bounds)
        let sut = HolderViewController()
        window.rootViewController = sut
        window.makeKeyAndVisible()
        _ = sut.view

        // When
        sut.tableView.delegate?.tableView?(sut.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        try await Task.sleep(nanoseconds: 50 * 1_000_000)

        // Then
        #expect(sut.presentedViewController is UINavigationController)
    }
}
