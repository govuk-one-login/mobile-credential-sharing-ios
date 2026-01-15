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
        
        // Check for the "Scan Credential" button
        let scanButton = app.buttons["Scan Credential"]
        XCTAssertTrue(scanButton.exists)
        
        // Verify it is functional (tapping it opens the camera permission settings sheet)
        scanButton.tap()
        let noPermissionText = app.staticTexts["Please enable camera permissions to continue"]
        let openSettingsBtn = app.staticTexts["Open Settings"].firstMatch
        XCTAssertTrue(noPermissionText.exists, "Camera permission prompt should appear.")
        XCTAssertTrue(openSettingsBtn.exists, "Open Settings button should appear.")
        let cancelBtn = app.buttons["Cancel"].firstMatch
        cancelBtn.tap()

        XCTAssertTrue(verifierNavBar.exists, "Should return to Verifier screen after tap.")

        // -- AC3 (Part B): Switch back to Holder
        app.tabBars.buttons["Holder"].tap()
        XCTAssertTrue(holderNavBar.exists)
    }
}
