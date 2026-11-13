import DesignSystem
import Foundation
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("ConsentViewModel Tests")
struct ConsentViewModelTests {
    private func presentation(
        _ attributes: [(String, Bool)],
        dvsName: String = "Yoti Ltd",
        docName: String = "driving licence"
    ) -> ConsentPresentation {
        ConsentPresentation(
            dvsName: dvsName,
            documentType: DocumentType(displayLabel: docName, documentIcon: UIImage()),
            attributes: attributes.map {
                ConsentAttribute(namespace: "org.iso.18013.5.1", identifier: $0.0, intentToRetain: $0.1)
            },
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!
        )
    }

    @Test("Static copy matches the design")
    func staticCopy() {
        #expect(
            GDSLocalisedString(stringKey: "consentTitle", bundle: .module).value
                == "Review what you’ll share"
        )
        #expect(
            GDSLocalisedString(stringKey: "consentWhatYoullShareHeading", bundle: .module).value
                == "What you’ll share"
        )
        #expect(
            GDSLocalisedString(stringKey: "consentCancelButton", bundle: .module).value
                == "Cancel and go back to documents"
        )
    }

    @Test("Agree button is pluralised for more than one attribute")
    func pluralAgreeButton() {
        let card = AttributesCardViewModel(presentation: presentation([("Name", true), ("Photo", false)]))
        #expect(ConsentViewModel.agreeButtonTitle(count: card.sharedCount) == "Agree and share 2 details")
    }

    @Test("Agree button is singular for exactly one attribute")
    func singularAgreeButton() {
        let card = AttributesCardViewModel(presentation: presentation([("Name", true)]))
        #expect(ConsentViewModel.agreeButtonTitle(count: card.sharedCount) == "Agree and share 1 detail")
    }

    @Test(
        "DVS name ending a sentence never produces a double period",
        arguments: ["Yoti Ltd", "Yoti Ltd.", "Yoti Ltd.."]
    )
    func sentenceEndPeriod(name: String) {
        let sentence = ConsentViewModel.organisationSentence(for: presentation([("Name", true)], dvsName: name))
        #expect(sentence == "The person doing the check is using an approved app powered by Yoti Ltd.")
    }

    @Test("DVS name mid-sentence keeps its own period")
    func midSentencePeriod() {
        let title = ConsentViewModel.readAboutButtonTitle(
            for: presentation([("Name", true), ("Photo", false)], dvsName: "Yoti Ltd.")
        )
        #expect(title == "Read about Yoti Ltd. and their privacy notice")
    }
}
