@testable import CredentialSharingUI
import SharingCryptoService
import SwiftCBOR
import Testing
import UIKit

@MainActor
@Suite("AttributeResultViewController Tests")
struct AttributeResultViewControllerTests {

    private func buildDeviceResponse(
        documents: [Document]? = nil
    ) -> DeviceResponse {
        DeviceResponse(
            documents: documents,
            documentErrors: nil,
            status: .ok
        )
    }

    private func buildDocument() -> Document {
        let item = IssuerSignedItem(
            digestID: 1,
            random: [0x01, 0x02],
            elementIdentifier: "family_name",
            elementValue: .utf8String("Smith")
        )
        let issuerSigned = IssuerSigned(
            nameSpaces: ["org.iso.18013.5.1": [item]],
            issuerAuth: [0x01, 0x02, 0x03]
        )
        return Document(
            docType: .mdl,
            issuerSigned: issuerSigned
        )
    }

    @Test("View has correct background colour")
    func backgroundColourIsSystemBackground() {
        let sut = AttributeResultViewController(deviceResponse: buildDeviceResponse())
        _ = sut.view

        #expect(sut.view.backgroundColor == .systemBackground)
    }

    @Test("Navigation back button is hidden")
    func navigationBackButtonHidden() {
        let sut = AttributeResultViewController(deviceResponse: buildDeviceResponse())
        _ = sut.view

        #expect(sut.navigationItem.hidesBackButton == true)
    }

    @Test("Title is set to Verification Result")
    func titleIsSet() {
        let sut = AttributeResultViewController(deviceResponse: buildDeviceResponse())
        _ = sut.view

        #expect(sut.title == "Verification Result")
    }

    @Test("Stack view is present with correct accessibility identifier")
    func stackViewHasAccessibilityIdentifier() {
        let sut = AttributeResultViewController(deviceResponse: buildDeviceResponse())
        _ = sut.view

        let stackView = sut.view.findView(with: "AttributeResultStackView")
        #expect(stackView != nil)
    }

    @Test("Displays success title label")
    func displaysSuccessTitle() {
        let sut = AttributeResultViewController(deviceResponse: buildDeviceResponse())
        _ = sut.view

        let titleLabel = sut.view.findLabel(with: "AttributeResultTitle")
        #expect(titleLabel?.text == "Document successfully Verified")
    }

    @Test("Displays document type for a valid document")
    func displaysDocType() {
        let document = buildDocument()
        let response = buildDeviceResponse(documents: [document])
        let sut = AttributeResultViewController(deviceResponse: response)
        _ = sut.view

        let labels = sut.view.findAllLabels()
        let docTypeLabel = labels.first { $0.text == "org.iso.18013.5.1.mDL" }
        #expect(docTypeLabel != nil)
    }

    @Test("Displays namespace")
    func displaysNamespace() {
        let document = buildDocument()
        let response = buildDeviceResponse(documents: [document])
        let sut = AttributeResultViewController(deviceResponse: response)
        _ = sut.view

        let labels = sut.view.findAllLabels()
        let nsLabel = labels.first { $0.text == "org.iso.18013.5.1" }
        #expect(nsLabel != nil)
    }

    @Test("Displays element identifier and value")
    func displaysElementData() {
        let document = buildDocument()
        let response = buildDeviceResponse(documents: [document])
        let sut = AttributeResultViewController(deviceResponse: response)
        _ = sut.view

        let labels = sut.view.findAllLabels()
        let attributeLabel = labels.first { $0.text?.contains("family_name") == true }
        #expect(attributeLabel != nil)
        #expect(attributeLabel?.text?.contains("Smith") == true)
    }
}

// MARK: - UIView Test Helpers

private extension UIView {
    func findView(with accessibilityIdentifier: String) -> UIView? {
        if self.accessibilityIdentifier == accessibilityIdentifier {
            return self
        }
        for subview in subviews {
            if let found = subview.findView(with: accessibilityIdentifier) {
                return found
            }
        }
        return nil
    }

    func findLabel(with accessibilityIdentifier: String) -> UILabel? {
        findView(with: accessibilityIdentifier) as? UILabel
    }

    func findAllLabels() -> [UILabel] {
        var labels: [UILabel] = []
        if let label = self as? UILabel {
            labels.append(label)
        }
        for subview in subviews {
            labels.append(contentsOf: subview.findAllLabels())
        }
        return labels
    }
}
