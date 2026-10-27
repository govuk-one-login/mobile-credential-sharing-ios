import Foundation
import SharingOrchestration
import Testing
import UIKit

@testable import CredentialSharingUI

@Suite("ConsentContent Tests")
struct ConsentContentTests {
    private func presentation(
        _ attributes: [(String, Bool)],
        dvsName: String = "Yoti Ltd",
        docName: String = "driving licence"
    ) -> ConsentPresentation {
        ConsentPresentation(
            dvsName: dvsName,
            documentType: DocumentType(displayLabel: docName, documentIcon: UIImage()),
            attributes: attributes.map {
                ConsentAttribute(namespace: "org.iso.18013.5.1", displayLabel: $0.0, intentToRetain: $0.1)
            },
            privacyPolicyURL: URL(string: "https://example.gov.uk/privacy")!
        )
    }

    @Test("Only non-retained attributes gives the no-details-kept variant (Variant AC1)")
    func noneKept() {
        let sut = ConsentContent(presentation: presentation([("Name", false), ("Photo", false)]))
        #expect(sut.variant == .noneKept)
        #expect(sut.sections.count == 1)
        #expect(sut.sections[0].heading == nil)
        #expect(sut.sections[0].items == ["Name", "Photo"])
        #expect(sut.sections[0].footnote == "These details will only be used for this check. They will not be saved.")
    }

    @Test("Only retained attributes gives the all-details-kept variant (Variant AC2)")
    func allKept() {
        let sut = ConsentContent(presentation: presentation([("Name", true)]))
        #expect(sut.variant == .allKept)
        #expect(sut.sections.count == 1)
        #expect(sut.sections[0].heading == nil)
        #expect(sut.sections[0].items == ["Name"])
        #expect(sut.sections[0].footnote == "Yoti Ltd will keep these details as a record of this check.")
    }

    @Test("Mixed attributes gives the some-details-kept variant (Variant AC3)")
    func someKept() {
        let sut = ConsentContent(presentation: presentation([("Name", true), ("Photo", false), ("Age", true)]))
        #expect(sut.variant == .someKept)
        #expect(sut.sections.count == 2)
        #expect(sut.sections[0].heading == "Yoti Ltd will keep these details as a record of this check:")
        #expect(sut.sections[0].items == ["Name", "Age"])
        #expect(sut.sections[1].heading == "Yoti Ltd will not keep:")
        #expect(sut.sections[1].items == ["Photo"])
        #expect(sut.sections.allSatisfy { $0.footnote == nil })
    }

    @Test("Static copy matches the design")
    func staticCopy() {
        #expect(ConsentContent.title == "Review what you’ll share")
        #expect(ConsentContent.whatYoullShareHeading == "What you’ll share")
        #expect(ConsentContent.cancelButtonTitle == "Cancel and go back to documents")
    }

    @Test("Count and document name are interpolated, and plural for more than one")
    func pluralCopy() {
        let sut = ConsentContent(presentation: presentation([("Name", true), ("Photo", false)]))
        #expect(sut.summary == "You’ll share 2 details from your driving licence")
        #expect(sut.agreeButtonTitle == "Agree and share 2 details")
    }

    @Test("Singular copy when exactly one attribute")
    func singularCopy() {
        let sut = ConsentContent(presentation: presentation([("Name", true)]))
        #expect(sut.summary == "You’ll share 1 detail from your driving licence")
        #expect(sut.agreeButtonTitle == "Agree and share 1 detail")
    }

    @Test("DVS name ending a sentence never produces a double period", arguments: ["Yoti Ltd", "Yoti Ltd.", "Yoti Ltd.."])
    func sentenceEndPeriod(name: String) {
        let sut = ConsentContent(presentation: presentation([("Name", true)], dvsName: name))
        #expect(sut.organisationSentence == "The person doing the check is using an approved app powered by Yoti Ltd.")
        #expect(sut.sections[0].footnote == "Yoti Ltd will keep these details as a record of this check.")
    }

    @Test("DVS name mid-sentence keeps its own period")
    func midSentencePeriod() {
        let sut = ConsentContent(presentation: presentation([("Name", true), ("Photo", false)], dvsName: "Yoti Ltd."))
        #expect(sut.readAboutButtonTitle == "Read about Yoti Ltd. and their privacy notice")
        #expect(sut.sections[0].heading == "Yoti Ltd. will keep these details as a record of this check:")
        #expect(sut.sections[1].heading == "Yoti Ltd. will not keep:")
    }
}
