import DesignSystem
import Foundation
import SharingCryptoService
import SharingOrchestration
import UIKit

// MARK: - SharingCardModel

public struct SharingCardModel: Equatable, Sendable {
    public let docType: DocType
    public let dvsName: String
    public let attributes: [ConsentAttribute]

    public init(docType: DocType, dvsName: String, attributes: [ConsentAttribute]) {
        self.docType = docType
        self.dvsName = dvsName
        self.attributes = attributes
    }
}

// MARK: - SharingCardViewModel

@MainActor
public struct SharingCardViewModel {

    // MARK: Nested types

    /// How a divider is inset within the card.
    private enum DividerInset {
        /// Used for the header divider, which separates the grey header block from the body
        case fullWidth
        /// Used between attribute rows, so the line starts just before the row
        case leading
    }

    // MARK: Type properties

    /// Standard 16px inset used for the card's own padding.
    private static let contentInset: CGFloat = DesignSystem.Spacing.default
    /// Custom lower padding for dividers in attribute rows
    private static let rowDividerLeadingInset: CGFloat = 14

    static let cardLineColour = UIColor(
        light: DesignSystem.Color.Base.grey3,
        dark: DesignSystem.Color.Base.grey3
    )

    /// Attributes retained by the verifier, in displayed order.
    public let keptAttributes: [ConsentAttribute]

    /// Attributes not retained by the verifier, in displayed order.
    public let notKeptAttributes: [ConsentAttribute]

    /// The total number of shared (recognised) attributes — the `[XX]` value.
    public var sharedCount: Int { keptAttributes.count + notKeptAttributes.count }

    // MARK: Composed content

    /// The ordered content items that make up the card body
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
        kept: [ConsentAttribute],
        notKept: [ConsentAttribute]
    ) -> [any ContentViewModel] {
        [headerRow(docType: docType, count: count)]
            + [divider(id: "sharing-card-header-divider", inset: .fullWidth)]
            + bodyItems(dvsName: dvsName, kept: kept, notKept: notKept)
    }

    private static func headerRow(docType: DocType, count: Int) -> SharingCardRowViewModel {
        SharingCardRowViewModel(
            title: headerLocalisedString(docType: docType, count: count),
            isGrey: true,
            leadingImage: SharingAttributeCatalog.documentIcon(for: docType),
            accessibilityIdentifier: "sharing-card-header"
        )
    }

    private static func bodyItems(
        dvsName: String,
        kept: [ConsentAttribute],
        notKept: [ConsentAttribute]
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

    private static func rows(for attributes: [ConsentAttribute]) -> [any ContentViewModel] {
        attributes.enumerated().flatMap { index, attribute -> [any ContentViewModel] in
            var items: [any ContentViewModel] = [row(for: attribute)]
            if index < attributes.count - 1 {
                items.append(divider(id: "sharing-card-row-divider-\(index)", inset: .leading))
            }
            return items
        }
    }

    private static func row(for attribute: ConsentAttribute) -> SharingCardRowViewModel {
        SharingCardRowViewModel(
            title: GDSLocalisedString(stringLiteral: attributeLabel(for: attribute)),
            isGrey: false,
            accessibilityIdentifier: "sharing-card-row-\(attribute.identifier)"
        )
    }

    /// `GDSDividerView` renders its height in physical pixels (`height / scale`),
    /// so passing `height = scale` yields a 1pt line matching the 1pt border.
    private static func divider(id: String, inset: DividerInset = .fullWidth) -> GDSDividerViewModel {
        let horizontalPadding: HorizontalPadding
        switch inset {
        case .fullWidth:
            horizontalPadding = .horizontal(0)
        case .leading:
            horizontalPadding = .leading(rowDividerLeadingInset)
        }
        return GDSDividerViewModel(
            height: UIScreen.main.scale,
            colour: cardLineColour,
            accessibilityIdentifier: id,
            verticalPadding: .vertical(0),
            horizontalPadding: horizontalPadding
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
    static func attributeLabel(for attribute: ConsentAttribute) -> String {
        var key: String
        var variableKeys: [String] = []
        let ageOverPrefix = "age_over_"
        if attribute.identifier.hasPrefix(ageOverPrefix) {
            key = "attr.age_over_NN"
            variableKeys = [String(attribute.identifier.dropFirst(ageOverPrefix.count))]
        } else {
            key = "attr.\(attribute.identifier)"
        }
        return GDSLocalisedString(stringKey: key, variableKeys: variableKeys, bundle: .module).value
    }

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

    static func normaliseDvsName(_ name: String) -> String {
        var trimmed = name
        while trimmed.hasSuffix(".") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }
}
