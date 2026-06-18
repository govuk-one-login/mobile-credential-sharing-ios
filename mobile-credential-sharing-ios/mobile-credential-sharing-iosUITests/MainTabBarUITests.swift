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
        XCTAssertTrue(verifierNavBar.waitForExistence(timeout: 2), "Should be on Verifier screen after tap.")
        
        // Check for the option buttons and verify credential button
        let option1Button = app.buttons["Photo and Age Over 21"]
        let option2Button = app.buttons["Name + Title (Retain) and Age Over 23"]
        let verifyCredentialButton = app.buttons["Verify Credential"]
        XCTAssertTrue(option1Button.exists)
        XCTAssertTrue(option2Button.exists)
        XCTAssertTrue(verifyCredentialButton.exists)
        
        // Select an option and tap Verify Credential to present the journey modal
        option1Button.tap()
        verifyCredentialButton.tap()
        XCTAssertFalse(verifyCredentialButton.isHittable, "Button should be behind presented modal.")
        
        // Dismiss the modal by swiping down on the top of the presented view
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        
        XCTAssertTrue(verifyCredentialButton.waitForExistence(timeout: 2), "Should return to Verifier screen after dismissal.")
        XCTAssertTrue(option1Button.isHittable, "Option buttons should be interactive again after dismissal.")

        // -- AC3 (Part B): Switch back to Holder
        app.tabBars.buttons["Holder"].tap()
        XCTAssertTrue(holderNavBar.exists)
    }
}
