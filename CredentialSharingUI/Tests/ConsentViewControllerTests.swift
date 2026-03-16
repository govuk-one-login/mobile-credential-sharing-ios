import Foundation
import SharingCryptoService
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ConsentViewController Tests")
struct ConsentViewControllerTests {
    
    @Test("View loads with correct title")
    func viewLoadsWithTitle() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let titleLabel = try #require(sut.view.subviews.first {
            ($0 as? UILabel)?.text == "Confirm the credential attributes to share"
        } as? UILabel)
        
        #expect(titleLabel.font == UIFont.systemFont(ofSize: 24, weight: .bold))
        #expect(titleLabel.textAlignment == .center)
    }
    
    @Test("View contains text view with device request details")
    func viewContainsTextView() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.isEditable == false)
        #expect(textView.isScrollEnabled == true)
    }
    
    @Test("Text view displays version")
    func textViewDisplaysVersion() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.text?.contains("Version: 1.0") == true)
    }
    
    @Test("Text view displays document type")
    func textViewDisplaysDocumentType() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.text?.contains("Document Type: org.iso.18013.5.1.mDL") == true)
    }
    
    @Test("Text view displays namespace")
    func textViewDisplaysNamespace() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        #expect(textView.text?.contains("Namespace: org.iso.18013.5.1") == true)
    }
    
    @Test("Text view displays all requested elements without intent to retain")
    func textViewDisplaysElementsWithoutIntentToRetain() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        let text = try #require(textView.text)
        
        #expect(text.contains("family_name: IntentToRetain = false"))
        #expect(text.contains("document_number: IntentToRetain = false"))
        #expect(text.contains("driving_privileges: IntentToRetain = false"))
        #expect(text.contains("issue_date: IntentToRetain = false"))
        #expect(text.contains("expiry_date: IntentToRetain = false"))
        #expect(text.contains("portrait: IntentToRetain = false"))
    }
    
    @Test("Text view displays all requested elements with intent to retain")
    func textViewDisplaysElementsWithIntentToRetain() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: true)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let textView = try #require(sut.view.subviews.first { $0 is UITextView } as? UITextView)
        let text = try #require(textView.text)
        
        #expect(text.contains("family_name: IntentToRetain = true"))
        #expect(text.contains("document_number: IntentToRetain = true"))
        #expect(text.contains("driving_privileges: IntentToRetain = true"))
        #expect(text.contains("issue_date: IntentToRetain = true"))
        #expect(text.contains("expiry_date: IntentToRetain = true"))
        #expect(text.contains("portrait: IntentToRetain = false"))
    }
    
    @Test("View contains Accept button")
    func viewContainsAcceptButton() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let acceptButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Accept"
        } as? UIButton)
        
        #expect(acceptButton.backgroundColor == .systemGreen)
    }
    
    @Test("View contains Deny button")
    func viewContainsDenyButton() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        let denyButton = try #require(sut.view.subviews.first {
            ($0 as? UIButton)?.title(for: .normal) == "Deny"
        } as? UIButton)
        
        #expect(denyButton.backgroundColor == .systemRed)
    }
    
    @Test("Navigation back button is hidden")
    func navigationBackButtonHidden() throws {
        let deviceRequest = try createDeviceRequest(withIntentToRetain: false)
        let sut = ConsentViewController(deviceRequest: deviceRequest)
        
        sut.viewDidLoad()
        
        #expect(sut.navigationItem.hidesBackButton == true)
    }
    
    // MARK: - Helper Methods
    
    private func createDeviceRequest(withIntentToRetain: Bool) throws -> DeviceRequest {
        let cbor = withIntentToRetain
            // swiftlint:disable:next line_length
            ? "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfVvZG9jdW1lbnRfbnVtYmVy9XJkcml2aW5nX3ByaXZpbGVnZXP1amlzc3VlX2RhdGX1a2V4cGlyeV9kYXRl9Whwb3J0cmFpdPQ"
            // swiftlint:disable:next line_length
            : "omd2ZXJzaW9uYzEuMGtkb2NSZXF1ZXN0c4GhbGl0ZW1zUmVxdWVzdNgYWJOiZ2RvY1R5cGV1b3JnLmlzby4xODAxMy41LjEubURMam5hbWVTcGFjZXOhcW9yZy5pc28uMTgwMTMuNS4xpmtmYW1pbHlfbmFtZfRvZG9jdW1lbnRfbnVtYmVy9HJkcml2aW5nX3ByaXZpbGVnZXP0amlzc3VlX2RhdGX0a2V4cGlyeV9kYXRl9Ghwb3J0cmFpdPQ"
        
        return try DeviceRequest(data: #require(Data(base64URLEncoded: cbor)))
    }
}
