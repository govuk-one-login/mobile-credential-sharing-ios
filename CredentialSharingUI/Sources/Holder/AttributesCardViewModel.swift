import DesignSystem
import Foundation
import SharingCryptoService
import SharingOrchestration
import UIKit

// MARK: - AttributesCardViewModel

@MainActor
public struct AttributesCardViewModel {

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

    // MARK: Catalog — order table

    private static let standard = AttributeGroup.Namespace.standard.rawValue
    private static let gb = AttributeGroup.Namespace.gb.rawValue
    private static let ageOverPrefix = "age_over_"

    /// Canonical display order of attributes. `intentToRetain` is omitted — it
    /// drives grouping, not ordering.
    private static let displayOrder: [(namespace: String, identifier: String)] = [
        (standard, "document_number"),
        (standard, "portrait"),
        (gb, "title"),
        (standard, "family_name"),
        (standard, "given_name"),
        (standard, "expiry_date"),
        (standard, "birth_date"),
        (standard, "age_over_NN"),
        (standard, "birth_place"),
        (standard, "resident_address"),
        (standard, "resident_city"),
        (standard, "resident_postal_code"),
        (standard, "issue_date"),
        (standard, "issuing_authority"),
        (standard, "issuing_country"),
        (standard, "un_distinguishing_sign"),
        (standard, "driving_privileges"),
        (gb, "provisional_driving_privileges"),
        (gb, "welsh_licence")
    ]

    // MARK: Stored content

    /// Attributes retained by the verifier, in displayed order.
    public let keptAttributes: [ConsentAttribute]

    /// Attributes not retained by the verifier, in displayed order.
    public let notKeptAttributes: [ConsentAttribute]

    /// The total number of shared (recognised) attributes — the `[XX]` value.
    public var sharedCount: Int { keptAttributes.count + notKeptAttributes.count }

    /// The ordered content items that make up the card body
    public let contentItems: [any ContentViewModel]

    /// The whole card as a single design-system card content item.
    public let card: GDSCardViewModel

    // MARK: Init

    public init(presentation: ConsentPresentation) {
        // Order once by the displayOrder, then group by retention so each group keeps its order
        let ordered = Self.ordered(presentation.attributes)
        let kept = ordered.filter { $0.intentToRetain }
        let notKept = ordered.filter { !$0.intentToRetain }

        self.keptAttributes = kept
        self.notKeptAttributes = notKept

        let items = Self.makeContentItems(
            documentType: presentation.documentType,
            dvsName: presentation.normalisedDvsName,
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
        documentType: DocumentType,
        dvsName: String,
        count: Int,
        kept: [ConsentAttribute],
        notKept: [ConsentAttribute]
    ) -> [any ContentViewModel] {
        [headerRow(documentType: documentType, count: count)]
            + [divider(id: "sharing-card-header-divider", inset: .fullWidth)]
            + bodyItems(dvsName: dvsName, kept: kept, notKept: notKept)
    }

    private static func headerRow(documentType: DocumentType, count: Int) -> AttributesCardRowViewModel {
        AttributesCardRowViewModel(
            title: headerLocalisedString(documentName: documentType.displayLabel, count: count),
            isGrey: true,
            leadingImage: documentType.documentIcon,
            accessibilityIdentifier: "sharing-card-header"
        )
    }

    private static func bodyItems(
        dvsName: String,
        kept: [ConsentAttribute],
        notKept: [ConsentAttribute]
    ) -> [any ContentViewModel] {
        // None-kept variant: rows then a single none-kept sentence.
        if kept.isEmpty {
            return rows(for: notKept)
                + [greySentence(key: "sharingCardNoneKeptSentence", id: "sharing-card-sentence")]
        }
        // All-kept variant: rows then a single kept-all sentence.
        if notKept.isEmpty {
            return rows(for: kept)
                + [greySentence(key: "sharingCardKeptAllSentence", variableKeys: [dvsName], id: "sharing-card-sentence")]
        }
        // Mixed variant: kept sentence + kept rows, then not-kept sentence + not-kept rows.
        return [greySentence(key: "sharingCardKeptRowSentence", variableKeys: [dvsName], id: "sharing-card-kept-lead-in")]
            + rows(for: kept)
            + [greySentence(key: "sharingCardNotKeptRowSentence", variableKeys: [dvsName], id: "sharing-card-not-kept-lead-in")]
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

    private static func row(for attribute: ConsentAttribute) -> AttributesCardRowViewModel {
        AttributesCardRowViewModel(
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
    ) -> AttributesCardRowViewModel {
        AttributesCardRowViewModel(
            title: GDSLocalisedString(stringKey: key, variableKeys: variableKeys, bundle: .module),
            isGrey: true,
            accessibilityIdentifier: id
        )
    }

    // MARK: - Label & header resolution

    /// Localised GDS label for a recognised attribute; unrecognised pairs (incl. known id under wrong namespace) pass through as the raw identifier.
    static func attributeLabel(for attribute: ConsentAttribute) -> String {
        if let age = parsedAgeOver(namespace: attribute.namespace, identifier: attribute.identifier) {
            return GDSLocalisedString(stringKey: "attr.age_over_NN", variableKeys: ["\(age)"], bundle: .module).value
        }
        guard orderIndex(for: attribute) < displayOrder.count else { return attribute.identifier }
        return GDSLocalisedString(stringKey: "attr.\(attribute.identifier)", bundle: .module).value
    }

    static func headerLocalisedString(documentName: String, count: Int) -> GDSLocalisedString {
        let countString = "\(count)"
        let boldFont = DesignSystem.Font.Base.bodySemiBold
        let stringKey = count == 1 ? "sharingCardHeader" : "sharingCardHeaderPlural"

        return GDSLocalisedString(
            stringKey: stringKey,
            variableKeys: [countString, documentName],
            stringAttributes: GDSStringAttributes(attributes: [
                (countString, [.font: boldFont]),
                (documentName, [.font: boldFont])
            ]),
            bundle: .module
        )
    }

    // MARK: - Ordering

    /// Attributes in canonical display order. Sorting is stable, so attributes
    /// with the same rank keep their input order.
    static func ordered(_ attributes: [ConsentAttribute]) -> [ConsentAttribute] {
        attributes.sorted { lhs, rhs in
            let lRank = orderIndex(for: lhs)
            let rRank = orderIndex(for: rhs)
            if lRank != rRank { return lRank < rRank }
            guard lhs.identifier.hasPrefix(ageOverPrefix),
                  rhs.identifier.hasPrefix(ageOverPrefix) else { return false }
            return lhs.identifier < rhs.identifier
        }
    }

    /// Display-order rank of an attribute; age-over shares one slot, unknown values sort last.
    private static func orderIndex(for attribute: ConsentAttribute) -> Int {
        let slotIdentifier = parsedAgeOver(namespace: attribute.namespace, identifier: attribute.identifier) != nil
            ? "age_over_NN"
            : attribute.identifier
        return displayOrder.firstIndex {
            $0.namespace == attribute.namespace && $0.identifier == slotIdentifier
        } ?? displayOrder.count
    }

    /// Gets age for `age_over_NN` identifier, else `nil`.
    static func parsedAgeOver(namespace: String, identifier: String) -> Int? {
        guard namespace == standard else { return nil }
        guard identifier.hasPrefix(ageOverPrefix) else { return nil }
        return Int(identifier.dropFirst(ageOverPrefix.count))
    }
}
