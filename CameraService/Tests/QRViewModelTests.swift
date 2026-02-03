@testable import CameraService
import Foundation
import Testing
import UIKit

// MARK: - QRViewModelTests

@MainActor
@Suite("QRViewModel URL Scanning Tests")
struct QRViewModelTests {

    let viewModel: QRViewModel

    init() {
        viewModel = QRViewModel(
            title: "Test Scanner",
            instructionText: "Test instructions",
            dismissScanner: { @MainActor in },
            presentInvalidQRError: { @MainActor in }
        )
    }

    // MARK: - URL Extraction Tests

    @Test("mdoc string is not extracted as URL")
    func mdocStringNotExtractedAsURL() {
        let testValue = "mdoc:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.example_payload_data_here"
        let extractedURL = viewModel.extractURL(from: testValue)

        // mdoc strings should not be extracted as URLs
        #expect(extractedURL == nil)

        // But they should be recognized as mdoc strings
        #expect(viewModel.isMdocString(testValue) == true)
    }


    @Test("URL with query parameters and fragment is extracted correctly")
    func urlWithParametersExtraction() {
        let testURL = "https://example.com/path?param=value&other=test#section"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "example.com")
        #expect(extractedURL?.path == "/path")
        #expect(extractedURL?.query == "param=value&other=test")
        #expect(extractedURL?.fragment == "section")
    }

    // MARK: - Non-URL Content Tests

    @Test("Empty string returns no URL")
    func emptyStringReturnsNil() {
        let testValue = ""
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

    @Test("Whitespace only returns no URL")
    func whitespaceReturnsNil() {
        let testValue = "   \n\t   "
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

    @Test("Unicode content without URL returns no URL")
    func unicodeContentReturnsNil() {
        let testValue = "这是中文内容 🎉 без URL"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

    // MARK: - Edge Cases

    @Test("URL with port number is extracted correctly")
    func urlWithPortExtraction() {
        let testURL = "https://test.com:8080/api"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.host == "test.com")
        #expect(extractedURL?.port == 8080)
        #expect(extractedURL?.path == "/api")
    }

    @Test("URL with username and password is extracted correctly")
    func urlWithCredentialsExtraction() {
        let testURL = "https://user:pass@test.com/secure"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.host == "test.com")
        #expect(extractedURL?.user == "user")
        #expect(extractedURL?.password == "pass")
        #expect(extractedURL?.path == "/secure")
    }

    @Test("Very long URL is extracted correctly")
    func longURLExtraction() {
        let testURL = "https://test.com/very/long/path/with/many/segments/and/parameters?param1=value1&param2=value2&param3=value3#section"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testURL)
        #expect(extractedURL?.pathComponents.count == 9) // includes root "/"
    }

    // MARK: - MDoc Validation Tests

    @Test("mdoc string is considered valid")
    func mdocStringValidation() {
        let testValue = "mdoc:testtesttesttesttesttesttesttest"
        #expect(viewModel.isMdocString(testValue) == true)
    }

    @Test("MDOC string (uppercase) is considered valid")
    func mdocStringUppercaseValidation() {
        let testValue = "MDOC:TESTTESTTESTTESTTESTTESTTESTTEST"
        #expect(viewModel.isMdocString(testValue) == true)
    }


    @Test("Plain text starting with mdoc is NOT considered valid mdoc")
    func nonMdocStringValidation() {
        let testValue = "mdocument: this is not a valid mdoc"
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("Regular text is not considered valid mdoc")
    func regularTextValidation() {
        let testValue = "Regular placeholder test code."
        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL == nil)
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("didScan with valid mdoc string handles correctly")
    func didScanWithValidMdocString() async {
        let testValue = "mdoc:eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.example_payload_data_here"

        // Verify it's recognized as mdoc string
        #expect(viewModel.isMdocString(testValue) == true)

        // didScan should complete without any issue (scanner dismisses, decoder called)
        await viewModel.didScan(value: testValue, in: UIView())
    }

    @Test("gov.uk URL is extracted correctly and not recognized as mdoc")
    func govUKURLValidation() async {
        let testURL = "https://www.gov.uk/government/path?param=value"

        let extractedURL = viewModel.extractURL(from: testURL)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testURL)
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "www.gov.uk")
        #expect(viewModel.isMdocString(testURL) == false)
    }

    @Test("non-URL content returns no URL and not recognized as mdoc")
    func nonURLContentValidation() async {
        let testValue = "plain text with no URL"

        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL == nil)
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("embedded gov.uk URL is extracted correctly from text and not recognized as mdoc")
    func embeddedGovUKURLValidation() async {
        let testValue = "GOV.UK LINK: https://www.gov.uk/guidance FOR TESTING"

        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == "https://www.gov.uk/guidance")
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "www.gov.uk")
        #expect(extractedURL?.path == "/guidance")
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("non-mdoc URL is extracted correctly and not recognized as mdoc")
    func nonMdocURLValidation() async {
        let testValue = "https://www.youtube.com/watch?v=example"

        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testValue)
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "www.youtube.com")
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("mailto URL is extracted but is not recognized as mdoc, so is not opened")
    func mailtoURLValidation() async {
        let testValue = "mailto:test@example.com"
        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testValue)
        #expect(viewModel.isMdocString(testValue) == false)
    }

    @Test("phone number is not extracted as URL and not recognized as mdoc")
    func phoneNumberValidation() async {
        let testValue = "+1-555-123-4567"
        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL == nil)
        #expect(viewModel.isMdocString(testValue) == false)
    }
}
