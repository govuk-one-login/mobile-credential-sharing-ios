import XCTest

final class MainTabBarUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testAppNavigationFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // -- AC1: App opens to the holder tab
        let holderNavBar = app.navigationBars["Holder"]
        XCTAssertTrue(holderNavBar.exists, "Should start on Holder screen")
        
        // -- AC2 (Part A): Switch to Verifier
        let verifierTab = app.tabBars.buttons["Verifier"]
        XCTAssertTrue(verifierTab.exists)
        verifierTab.tap()
        
        // -- AC2: Verifier tab content
        
        // Check we are now on the Verifier screen
        let verifierNavBar = app.navigationBars["Verifier"]
        XCTAssertTrue(verifierNavBar.exists, "Should be on Verifier screen after tap.")
        
        // Check for the "Start verification journey" button
        let startVerificationButton = app.buttons["Start verification journey"]
        XCTAssertTrue(startVerificationButton.exists)
        
        // Tapping the button presents the verifier journey modal
        startVerificationButton.tap()
        XCTAssertFalse(startVerificationButton.isHittable, "Button should be behind presented modal.")
        
        // Dismiss the modal by swiping down on the top of the presented view
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        
        XCTAssertTrue(startVerificationButton.waitForExistence(timeout: 2), "Should return to Verifier screen after dismissal.")
        XCTAssertTrue(startVerificationButton.isHittable, "Button should be interactive again after dismissal.")

        // -- AC3 (Part B): Switch back to Holder
        app.tabBars.buttons["Holder"].tap()
        XCTAssertTrue(holderNavBar.exists)
    }
}
