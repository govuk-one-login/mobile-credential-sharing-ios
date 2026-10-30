import DesignSystem
import SharingCryptoService
import Testing
import UIKit

@testable import CredentialSharingUI

@MainActor
@Suite("Sharing Card Component Tests")
struct SharingCardViewModelTests {

    // MARK: - Helpers

    private let standard = "org.iso.18013.5.1"
    private let gb = "org.iso.18013.5.1.GB"

    private func attribute(
        _ identifier: String,
        namespace: String = "org.iso.18013.5.1",
        kept: Bool = false
    ) -> SharingCardAttribute {
        SharingCardAttribute(namespace: namespace, identifier: identifier, intentToRetain: kept)
    }

    private func makeViewModel(
        attributes: [SharingCardAttribute],
        dvsName: String = "Yoti Ltd"
    ) -> SharingCardViewModel {
        SharingCardViewModel(
            model: SharingCardModel(docType: .mdl, dvsName: dvsName, attributes: attributes)
        )
    }

    private func contentIdentifiers(in viewModel: SharingCardViewModel) -> [String] {
        viewModel.contentItems.compactMap { $0.accessibilityIdentifier }
    }

    // MARK: - Attribute label mapping

    @Test("Standard-namespace identifiers map to their GDS label keys")
    func standardLabelKeys() {
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: standard, identifier: "document_number") == "attr.document_number")
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: standard, identifier: "portrait") == "attr.portrait")
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: standard, identifier: "un_distinguishing_sign") == "attr.un_distinguishing_sign")
    }

    @Test("GB-namespace identifiers map to their GDS label keys")
    func gbLabelKeys() {
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: gb, identifier: "title") == "attr.title")
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: gb, identifier: "provisional_driving_privileges") == "attr.provisional_driving_privileges")
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: gb, identifier: "welsh_licence") == "attr.welsh_licence")
    }

    @Test("age_over_NN collapses onto the single age key and carries the NN value")
    func ageOverMapping() {
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: standard, identifier: "age_over_18") == "attr.age_over_NN")
        #expect(SharingAttributeCatalog.labelVariableKeys(namespace: standard, identifier: "age_over_18") == ["18"])
        #expect(SharingAttributeCatalog.labelVariableKeys(namespace: standard, identifier: "age_over_21") == ["21"])
    }

    @Test("Unknown identifiers have no label key")
    func unknownLabelKey() {
        #expect(SharingAttributeCatalog.attributeLabelKey(namespace: standard, identifier: "not_a_real_attribute") == nil)
    }

    @Test("Resolved English labels match the GDS copy")
    func resolvedEnglishLabels() {
        #expect(SharingCardViewModel.attributeLabel(for: attribute("document_number")) == "Licence number")
        #expect(SharingCardViewModel.attributeLabel(for: attribute("family_name")) == "Last name")
        #expect(SharingCardViewModel.attributeLabel(for: attribute("given_name")) == "First name(s)")
        #expect(SharingCardViewModel.attributeLabel(for: attribute("age_over_18")) == "If you’re over 18")
    }

    // MARK: - Ordering

    @Test("Attributes are returned in the canonical GDS order, not request order")
    func canonicalOrdering() {
        // Supplied deliberately out of order.
        let input = [
            attribute("expiry_date"),
            attribute("portrait"),
            attribute("document_number"),
            attribute("family_name"),
            attribute("given_name"),
            attribute("title", namespace: gb)
        ]

        let orderedIdentifiers = SharingAttributeCatalog.ordered(input).map(\.identifier)

        #expect(orderedIdentifiers == [
            "document_number",
            "portrait",
            "title",
            "family_name",
            "given_name",
            "expiry_date"
        ])
    }

    @Test("Repeated age_over_NN attributes are ordered lowest to highest NN in the age slot")
    func ageOverOrdering() {
        let input = [
            attribute("birth_date"),
            attribute("age_over_21"),
            attribute("age_over_18"),
            attribute("age_over_65"),
            attribute("birth_place")
        ]

        let orderedIdentifiers = SharingAttributeCatalog.ordered(input).map(\.identifier)

        #expect(orderedIdentifiers == [
            "birth_date",
            "age_over_18",
            "age_over_21",
            "age_over_65",
            "birth_place"
        ])
    }

    @Test("Unmapped attributes are kept and sorted to the bottom of the list")
    func unmappedSortedToBottom() {
        let input = [
            attribute("family_name"),
            attribute("totally_unknown"),
            attribute("given_name")
        ]

        let orderedIdentifiers = SharingAttributeCatalog.ordered(input).map(\.identifier)
        // Mapped attributes keep canonical order; the unmapped one is retained
        // and placed last (rendered later using its raw identifier).
        #expect(orderedIdentifiers == ["family_name", "given_name", "totally_unknown"])
    }

    @Test("Multiple unmapped attributes keep their incoming order at the bottom")
    func multipleUnmappedPreserveOrder() {
        let input = [
            attribute("zzz_unknown"),
            attribute("document_number"),
            attribute("aaa_unknown")
        ]

        let orderedIdentifiers = SharingAttributeCatalog.ordered(input).map(\.identifier)
        // document_number is mapped (first); the two unmapped ones follow in
        // the order they arrived, not alphabetically.
        #expect(orderedIdentifiers == ["document_number", "zzz_unknown", "aaa_unknown"])
    }

    // MARK: - Document mapping

    @Test("mDL maps to its document name key and attempts icon load")
    func documentMapping() {
        #expect(SharingAttributeCatalog.documentNameKey(for: .mdl) == "mdlDocumentName")
        // The SVG asset ships under DCMAW-23705; loading must not crash whether
        // or not it is present.
        _ = SharingAttributeCatalog.documentIcon(for: .mdl)
    }

    // MARK: - Kept / not-kept split resolution

    @Test("All attributes not kept: everything lands in notKept")
    func splitNoneKept() {
        let viewModel = makeViewModel(attributes: [
            attribute("family_name", kept: false),
            attribute("given_name", kept: false)
        ])
        #expect(viewModel.keptAttributes.isEmpty)
        #expect(!viewModel.notKeptAttributes.isEmpty)
    }

    @Test("All attributes kept: everything lands in kept")
    func splitAllKept() {
        let viewModel = makeViewModel(attributes: [
            attribute("family_name", kept: true),
            attribute("given_name", kept: true)
        ])
        #expect(!viewModel.keptAttributes.isEmpty)
        #expect(viewModel.notKeptAttributes.isEmpty)
    }

    @Test("Mixed retention populates both splits")
    func splitSomeKept() {
        let viewModel = makeViewModel(attributes: [
            attribute("family_name", kept: true),
            attribute("given_name", kept: false)
        ])
        #expect(!viewModel.keptAttributes.isEmpty)
        #expect(!viewModel.notKeptAttributes.isEmpty)
    }

    @Test("Empty attribute set leaves both splits empty")
    func splitEmpty() {
        let viewModel = makeViewModel(attributes: [])
        #expect(viewModel.keptAttributes.isEmpty)
        #expect(viewModel.notKeptAttributes.isEmpty)
    }

    // MARK: - Shared count & split

    @Test("sharedCount counts all shared attributes, including unmapped ones")
    func sharedCount() {
        let viewModel = makeViewModel(attributes: [
            attribute("family_name"),
            attribute("given_name"),
            attribute("totally_unknown")
        ])
        // Unmapped attributes are still shared, so they count toward [XX].
        #expect(viewModel.sharedCount == 3)
    }

    @Test("Kept and not-kept splits preserve canonical order")
    func keptSplitOrdering() {
        let viewModel = makeViewModel(attributes: [
            attribute("given_name", kept: true),
            attribute("document_number", kept: true),
            attribute("expiry_date", kept: false),
            attribute("family_name", kept: false)
        ])

        #expect(viewModel.keptAttributes.map(\.identifier) == ["document_number", "given_name"])
        #expect(viewModel.notKeptAttributes.map(\.identifier) == ["family_name", "expiry_date"])
    }
}

// MARK: - Card composition

@MainActor
extension SharingCardViewModelTests {

    // MARK: - Card composition: header

    @Test("Card exposes a header with the sharing-card-header identifier")
    func cardHasHeader() {
        let viewModel = makeViewModel(attributes: [attribute("family_name")])
        #expect(contentIdentifiers(in: viewModel).contains("sharing-card-header"))
        #expect(viewModel.card.accessibilityIdentifier == "sharing-card")
    }

    @Test("Header string includes the count and UK driving licence name")
    func headerStringContent() {
        let header = SharingCardViewModel.headerLocalisedString(docType: .mdl, count: 3)
        #expect(header.value == "You’ll share 3 details from your UK driving licence")
        // The attributed value bolds the count and document name substrings.
        #expect(header.attributedValue != nil)
    }

    @Test("A divider sits directly beneath the header row")
    func headerIsFollowedByDivider() {
        let viewModel = makeViewModel(attributes: [attribute("family_name")])
        let items = viewModel.contentItems

        guard let headerIndex = items.firstIndex(where: {
            $0.accessibilityIdentifier == "sharing-card-header"
        }) else {
            Issue.record("header row not present")
            return
        }

        // The item immediately after the header must be the header divider.
        #expect(items.indices.contains(headerIndex + 1))
        #expect(items[headerIndex + 1].accessibilityIdentifier == "sharing-card-header-divider")
    }

    @Test("Header divider spans full width within the card borders (zero horizontal inset)")
    func headerDividerIsFullWidth() {
        let viewModel = makeViewModel(attributes: [attribute("family_name")])

        guard let divider = viewModel.contentItems.first(where: {
            $0.accessibilityIdentifier == "sharing-card-header-divider"
        }) else {
            Issue.record("header divider not present")
            return
        }

        // Full width = no inset on either side; the card applies each item's
        // own horizontal padding, so zero here means border-to-border.
        guard case .horizontal(let inset)? = divider.horizontalPadding else {
            Issue.record("header divider does not use symmetric .horizontal padding")
            return
        }
        #expect(inset == 0)
    }

    // MARK: - Card composition: none kept variant

    @Test("None-kept variant lists the not-kept rows then the no-save sentence")
    func noneKeptComposition() {
        let viewModel = makeViewModel(attributes: [
            attribute("family_name", kept: false),
            attribute("given_name", kept: false)
        ])

        #expect(viewModel.keptAttributes.isEmpty)

        let ids = contentIdentifiers(in: viewModel)
        #expect(ids.contains("sharing-card-header"))
        #expect(ids.contains("sharing-card-row-family_name"))
        #expect(ids.contains("sharing-card-row-given_name"))
        #expect(ids.contains("sharing-card-sentence"))
        // No "some kept" lead-ins when nothing is kept.
        #expect(!ids.contains("sharing-card-kept-lead-in"))
        #expect(!ids.contains("sharing-card-not-kept-lead-in"))
    }

    // MARK: - Card composition: all kept variant

    @Test("All-kept variant lists the kept rows then the keep-as-record sentence")
    func allKeptComposition() {
        let viewModel = makeViewModel(attributes: [
            attribute("document_number", kept: true),
            attribute("portrait", kept: true)
        ])

        #expect(viewModel.notKeptAttributes.isEmpty)

        let ids = contentIdentifiers(in: viewModel)
        #expect(ids.contains("sharing-card-row-document_number"))
        #expect(ids.contains("sharing-card-row-portrait"))
        #expect(ids.contains("sharing-card-sentence"))
        #expect(!ids.contains("sharing-card-kept-lead-in"))
        #expect(!ids.contains("sharing-card-not-kept-lead-in"))
    }

    // MARK: - Card composition: some kept variant

    @Test("Some-kept variant has kept lead-in + kept rows, then not-kept lead-in + not-kept rows")
    func someKeptComposition() {
        let viewModel = makeViewModel(attributes: [
            attribute("document_number", kept: true),
            attribute("family_name", kept: false)
        ])

        #expect(!viewModel.keptAttributes.isEmpty)
        #expect(!viewModel.notKeptAttributes.isEmpty)

        let ids = contentIdentifiers(in: viewModel)
        #expect(ids.contains("sharing-card-kept-lead-in"))
        #expect(ids.contains("sharing-card-row-document_number"))
        #expect(ids.contains("sharing-card-not-kept-lead-in"))
        #expect(ids.contains("sharing-card-row-family_name"))
        // The some-kept variant has no standalone retention sentence.
        #expect(!ids.contains("sharing-card-sentence"))

        // The kept lead-in must appear before the not-kept lead-in.
        let keptIndex = ids.firstIndex(of: "sharing-card-kept-lead-in")
        let notKeptIndex = ids.firstIndex(of: "sharing-card-not-kept-lead-in")
        #expect(keptIndex != nil && notKeptIndex != nil)
        if let keptIndex, let notKeptIndex {
            #expect(keptIndex < notKeptIndex)
        }
    }

    @Test("Dividers separate consecutive attribute rows")
    func rowDividers() {
        let viewModel = makeViewModel(attributes: [
            attribute("document_number", kept: false),
            attribute("portrait", kept: false),
            attribute("family_name", kept: false)
        ])

        let ids = contentIdentifiers(in: viewModel)
        // Three rows → two inter-row dividers (indices 0 and 1).
        #expect(ids.contains("sharing-card-row-divider-0"))
        #expect(ids.contains("sharing-card-row-divider-1"))
        #expect(!ids.contains("sharing-card-row-divider-2"))
    }

    // MARK: - DVS name normalisation

    @Test("DVS name trailing periods are stripped")
    func dvsNameNormalisation() {
        #expect(SharingCardViewModel.normaliseDvsName("Yoti Ltd.") == "Yoti Ltd")
        #expect(SharingCardViewModel.normaliseDvsName("Yoti Ltd") == "Yoti Ltd")
        #expect(SharingCardViewModel.normaliseDvsName("Yoti Ltd...") == "Yoti Ltd")
    }
}
