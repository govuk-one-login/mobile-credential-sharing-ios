import DesignSystem
import Foundation
import SharingCryptoService
import UIKit

// MARK: - SharingCardModel

public struct SharingCardModel: Equatable, Sendable {
    public let docType: DocType
    public let dvsName: String
    public let attributes: [SharingCardAttribute]

    public init(docType: DocType, dvsName: String, attributes: [SharingCardAttribute]) {
        self.docType = docType
        self.dvsName = dvsName
        self.attributes = attributes
    }
}

// MARK: - SharingCardViewModel

@MainActor
public struct SharingCardViewModel {

    // MARK: Type properties

    /// Standard 16px inset used for the card's own padding and for inset
    /// dividers.
    private static let contentInset: CGFloat = DesignSystem.Spacing.default

    /// Border and divider colour for the card: Grey/3 in both light and dark
    /// mode, per the design spec. (The design-system `Dividers.card` token is
    /// Grey/1 in light mode, so it is not used here.)
    static let cardLineColour = UIColor(
        light: DesignSystem.Color.Base.grey3,
        dark: DesignSystem.Color.Base.grey3
    )

    // MARK: Resolved model (testable surface)

    /// Attributes retained by the verifier, in canonical GDS order.
    public let keptAttributes: [SharingCardAttribute]

    /// Attributes not retained by the verifier, in canonical GDS order.
    public let notKeptAttributes: [SharingCardAttribute]

    /// The total number of shared (recognised) attributes — the `[XX]` value.
    public var sharedCount: Int { keptAttributes.count + notKeptAttributes.count }

    // MARK: Composed content

    /// The ordered content items that make up the card body (header, rows,
    /// dividers, lead-ins and sentences). Exposed for composition and testing.
    public let contentItems: [any ContentViewModel]

    /// The whole card as a single design-system card content item.
    public let card: GDSCardViewModel

    // MARK: Init

    public init(model: SharingCardModel) {
        let ordered = SharingAttributeCatalog.ordered(model.attributes)
        let kept = ordered.filter { $0.intentToRetain }
        let notKept = ordered.filter { !$0.intentToRetain }

        self.keptAttributes = kept
        self.notKeptAttributes = notKept

        let items = Self.makeContentItems(
            docType: model.docType,
            dvsName: Self.normaliseDvsName(model.dvsName),
            count: ordered.count,
            kept: kept,
            notKept: notKept
        )
        self.contentItems = items
        self.card = GDSCardViewModel(
            backgroundColour: DesignSystem.Color.Backgrounds.card,
            borderStyle: BorderStyle(width: 1, color: Self.cardLineColour),
            cornerRadius: DesignSystem.CornerRadius.default,
            accessibilityIdentifier: "sharing-card",
            verticalPadding: .vertical(Self.contentInset),
            horizontalPadding: .horizontal(Self.contentInset)
        ) {
            items
        }
    }

    // MARK: - Card composition

    private static func makeContentItems(
        docType: DocType,
        dvsName: String,
        count: Int,
        kept: [SharingCardAttribute],
        notKept: [SharingCardAttribute]
    ) -> [any ContentViewModel] {
        [headerRow(docType: docType, count: count)]
            + [divider(id: "sharing-card-header-divider", fullWidth: true)]
            + bodyItems(dvsName: dvsName, kept: kept, notKept: notKept)
    }

    /// The grey header row: the 70x50 document image on the left and the
    /// rich-text "You'll share XX details from XX" copy (count and document
    /// name in semi-bold) on the right.
    private static func headerRow(docType: DocType, count: Int) -> SharingCardRowViewModel {
        SharingCardRowViewModel(
            title: headerLocalisedString(docType: docType, count: count),
            isGrey: true,
            leadingImage: SharingAttributeCatalog.documentIcon(for: docType),
            accessibilityIdentifier: "sharing-card-header"
        )
    }

    /// The body, decided by the kept / not-kept split:
    /// - only not-kept: the rows + a single "will not be saved" sentence.
    /// - only kept: the rows + a single "will keep these details" sentence.
    /// - a mix: a "will keep" lead-in + kept rows, then a "will not keep"
    ///   lead-in + not-kept rows.
    private static func bodyItems(
        dvsName: String,
        kept: [SharingCardAttribute],
        notKept: [SharingCardAttribute]
    ) -> [any ContentViewModel] {
        if kept.isEmpty {
            return rows(for: notKept)
                + [greySentence(key: "sharingCardNoneKeptSentence", id: "sharing-card-sentence")]
        }
        if notKept.isEmpty {
            return rows(for: kept)
                + [greySentence(key: "sharingCardKeptAllSentence", variableKeys: [dvsName], id: "sharing-card-sentence")]
        }
        return [greySentence(key: "sharingCardKeptLeadIn", variableKeys: [dvsName], id: "sharing-card-kept-lead-in")]
            + rows(for: kept)
            + [greySentence(key: "sharingCardNotKeptLeadIn", variableKeys: [dvsName], id: "sharing-card-not-kept-lead-in")]
            + rows(for: notKept)
    }

    // MARK: - Content item builders

    /// One attribute row per attribute, each followed by a full-width divider
    /// except the last (the card border closes the final row). Dividers run
    /// edge-to-edge so every line in the card — border, header divider and row
    /// dividers — reads as the same Grey/3 hairline.
    private static func rows(for attributes: [SharingCardAttribute]) -> [any ContentViewModel] {
        attributes.enumerated().flatMap { index, attribute -> [any ContentViewModel] in
            var items: [any ContentViewModel] = [row(for: attribute)]
            if index < attributes.count - 1 {
                items.append(divider(id: "sharing-card-row-divider-\(index)", fullWidth: true))
            }
            return items
        }
    }

    /// A plain (non-grey) attribute row. The row view insets its text to match
    /// the grey rows, so no extra card-level padding is needed.
    private static func row(for attribute: SharingCardAttribute) -> SharingCardRowViewModel {
        SharingCardRowViewModel(
            title: GDSLocalisedString(stringLiteral: attributeLabel(for: attribute)),
            isGrey: false,
            accessibilityIdentifier: "sharing-card-row-\(attribute.identifier)"
        )
    }

    /// A card divider line. Uses the same Grey/3 colour and the same 1pt visual
    /// weight as the card border so every line in the card matches. `fullWidth`
    /// runs it border-to-border; otherwise it is inset 16px on each side.
    ///
    /// `GDSDividerView` renders its height in physical pixels (`height / scale`),
    /// so passing `height = scale` yields a 1pt line matching the 1pt border.
    private static func divider(id: String, fullWidth: Bool = false) -> GDSDividerViewModel {
        GDSDividerViewModel(
            height: UIScreen.main.scale,
            colour: cardLineColour,
            accessibilityIdentifier: id,
            verticalPadding: .vertical(0),
            horizontalPadding: .horizontal(fullWidth ? 0 : contentInset)
        )
    }

    /// A grey full-width retention sentence / lead-in row (no leading image).
    private static func greySentence(
        key: String,
        variableKeys: [String] = [],
        id: String
    ) -> SharingCardRowViewModel {
        SharingCardRowViewModel(
            title: GDSLocalisedString(stringKey: key, variableKeys: variableKeys, bundle: .module),
            isGrey: true,
            accessibilityIdentifier: id
        )
    }

    // MARK: - Label & header resolution

    /// The localised GDS label for an attribute, with `age_over_NN` resolved.
    static func attributeLabel(for attribute: SharingCardAttribute) -> String {
        guard let key = SharingAttributeCatalog.attributeLabelKey(
            namespace: attribute.namespace,
            identifier: attribute.identifier
        ) else {
            return attribute.identifier
        }
        let variableKeys = SharingAttributeCatalog.labelVariableKeys(
            namespace: attribute.namespace,
            identifier: attribute.identifier
        )
        return GDSLocalisedString(stringKey: key, variableKeys: variableKeys, bundle: .module).value
    }

    /// Builds the header as a `GDSLocalisedString` whose `attributedValue`
    /// renders the count and document name in semi-bold against regular body
    /// copy. The bold segments are matched in the resolved string.
    static func headerLocalisedString(docType: DocType, count: Int) -> GDSLocalisedString {
        let documentName = documentName(for: docType)
        let countString = "\(count)"
        let boldFont = DesignSystem.Font.Base.bodySemiBold

        return GDSLocalisedString(
            stringKey: "sharingCardHeader",
            variableKeys: [countString, documentName],
            stringAttributes: GDSStringAttributes(attributes: [
                (countString, [.font: boldFont]),
                (documentName, [.font: boldFont])
            ]),
            bundle: .module
        )
    }

    private static func documentName(for docType: DocType) -> String {
        guard let key = SharingAttributeCatalog.documentNameKey(for: docType) else {
            return ""
        }
        return GDSLocalisedString(stringKey: key, bundle: .module).value
    }

    /// Strips trailing periods from the raw DVS name so sentence templates can
    /// control their own punctuation. Mirrors `ConsentViewController`.
    static func normaliseDvsName(_ name: String) -> String {
        var trimmed = name
        while trimmed.hasSuffix(".") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }
}
