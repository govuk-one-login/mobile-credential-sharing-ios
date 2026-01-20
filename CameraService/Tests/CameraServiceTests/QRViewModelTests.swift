@testable import CameraService
import Foundation
import Testing
import UIKit

// MARK: - QRViewModelTests

@MainActor
@Suite("QRViewModel URL Scanning Tests")
struct QRViewModelTests {

    let viewModel: QRViewModel
    let mockView: UIView

    init() {
        viewModel = QRViewModel(
            title: "Test Scanner",
            instructionText: "Test instructions",
            dismissScanner: { @MainActor in }
        )
        mockView = UIView()
    }

    // MARK: - URL Extraction Tests

    @Test("Valid HTTP URL is extracted correctly")
    func httpURLExtraction() {
        let testURL = "http://www.test.com"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testURL)
        #expect(extractedURL?.scheme == "http")
        #expect(extractedURL?.host == "www.test.com")
    }

    @Test("Valid HTTPS URL is extracted correctly")
    func httpsURLExtraction() {
        let testURL = "https://secure.test.com/path"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testURL)
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "secure.test.com")
        #expect(extractedURL?.path == "/path")
    }

    @Test("Gov.uk URL is extracted correctly")
    func govUKURLExtraction() {
        let testURL = "https://www.gov.uk/government"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.host?.contains("gov.uk") == true)
        #expect(extractedURL?.scheme == "https")
    }

    @Test("Gov.uk subdomain URL is extracted correctly")
    func govUKSubdomainExtraction() {
        let testURL = "https://apply.gov.uk/passport"
        let extractedURL = viewModel.extractURL(from: testURL)

        #expect(extractedURL != nil)
        #expect(extractedURL?.host == "apply.gov.uk")
        #expect(extractedURL?.host?.contains("gov.uk") == true)
    }

    @Test("URL embedded in text is extracted")
    func embeddedURLExtraction() {
        let testValue = "testtesttesttest test https://www.test.com test test"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == "https://www.test.com")
        #expect(extractedURL?.scheme == "https")
    }

    @Test("First URL in text with multiple URLs is extracted")
    func multipleURLsExtraction() {
        let testValue = "https://www.first.com and https://www.second.com"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == "https://www.first.com")
    }

    @Test("URL without scheme is detected by NSDataDetector")
    func urlWithoutSchemeExtraction() {
        let testValue = "www.example.com"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL != nil)
        #expect(extractedURL?.host == "www.example.com")
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

    @Test("Plain text returns no URL")
    func plainTextReturnsNil() {
        let testValue = "plain text with no URL"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

    @Test("Number content returns no URL")
    func numberContentReturnsNil() {
        let testValue = "1234567890"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

    @Test("Email address opens as mailto:")
    func emailAddressReturnsNil() {
        let testValue = "test@example.com"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL?.absoluteString == "mailto:test@example.com")
    }

    @Test("Phone number returns no URL")
    func phoneNumberReturnsNil() {
        let testValue = "+44 123 456 7890"
        let extractedURL = viewModel.extractURL(from: testValue)

        #expect(extractedURL == nil)
    }

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

    // MARK: - didScan Integration Tests

    @Test("didScan with valid URL extracts URL correctly")
    func didScanWithValidURL() async {
        let testURL = "https://www.test.com/path?param=value"

        let extractedURL = viewModel.extractURL(from: testURL)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == testURL)
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "www.test.com")
        #expect(extractedURL?.path == "/path")
        #expect(extractedURL?.query == "param=value")

        // didScan should complete without any issue
        await viewModel.didScan(value: testURL, in: mockView)
    }

    @Test("didScan with non-URL content handles gracefully")
    func didScanWithNonURL() async {
        let testValue = "plain text with no URL"

        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL == nil)

        // didScan should complete without any issue
        await viewModel.didScan(value: testValue, in: mockView)
    }

    @Test("didScan with embedded URL extracts correctly")
    func didScanWithEmbeddedURL() async {
        let testValue = "GOV.UK LINK: https://www.gov.uk/guidance FOR TESTING"

        let extractedURL = viewModel.extractURL(from: testValue)
        #expect(extractedURL != nil)
        #expect(extractedURL?.absoluteString == "https://www.gov.uk/guidance")
        #expect(extractedURL?.scheme == "https")
        #expect(extractedURL?.host == "www.gov.uk")
        #expect(extractedURL?.path == "/guidance")

        // didScan should complete without any issue
        await viewModel.didScan(value: testValue, in: mockView)
    }
}
