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
        
        // Check for the drop-down menus and verify credential button
        let attributeGroupMenu = app.buttons["AttributeGroupMenuButton"]
        let readerAuthMenu = app.buttons["ReaderAuthMenuButton"]
        let verifyCredentialButton = app.buttons["Verify Credential"]
        XCTAssertTrue(attributeGroupMenu.exists)
        XCTAssertTrue(readerAuthMenu.exists)
        XCTAssertTrue(verifyCredentialButton.exists)

        // Both drop-downs default to their "valid" presets
        XCTAssertEqual(attributeGroupMenu.label, "Photo and Age Over 21")
        XCTAssertEqual(readerAuthMenu.label, "Valid")

        // Open the attribute-group drop-down and pick a different option (single-select)
        attributeGroupMenu.tap()
        let otherAttribute = app.buttons["Name + Title (Retain) and Age Over 23"]
        XCTAssertTrue(otherAttribute.waitForExistence(timeout: 2), "Attribute drop-down should present its options.")
        otherAttribute.tap()

        // Tap Verify Credential to present the journey modal
        verifyCredentialButton.tap()
        XCTAssertFalse(verifyCredentialButton.isHittable, "Button should be behind presented modal.")
        
        // Dismiss the modal by swiping down on the top of the presented view
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        start.press(forDuration: 0.1, thenDragTo: end)
        
        XCTAssertTrue(verifyCredentialButton.waitForExistence(timeout: 2), "Should return to Verifier screen after dismissal.")
        XCTAssertTrue(attributeGroupMenu.isHittable, "Drop-down menus should be interactive again after dismissal.")

        // -- AC3 (Part B): Switch back to Holder
        app.tabBars.buttons["Holder"].tap()
        XCTAssertTrue(holderNavBar.exists)
    }
}
