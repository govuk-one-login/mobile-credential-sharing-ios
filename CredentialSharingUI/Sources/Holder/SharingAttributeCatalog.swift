import DesignSystem
import Foundation
import SharingCryptoService
import SharingOrchestration
import UIKit

// MARK: - SharingAttributeCatalog

/// GDS-aligned mapping, ordering and iconography for the "Agree to Share" card.

public enum SharingAttributeCatalog {

    // MARK: Nested types

    private struct AttributeKey: Hashable {
        let namespace: String
        let identifier: String
    }

    // MARK: Namespaces

    private static let standard = AttributeGroup.Namespace.standard.rawValue
    private static let gb = AttributeGroup.Namespace.gb.rawValue

    // MARK: Order table

    private static let displayOrder: [AttributeKey] = [
        AttributeKey(namespace: standard, identifier: "document_number"),
        AttributeKey(namespace: standard, identifier: "portrait"),
        AttributeKey(namespace: gb, identifier: "title"),
        AttributeKey(namespace: standard, identifier: "family_name"),
        AttributeKey(namespace: standard, identifier: "given_name"),
        AttributeKey(namespace: standard, identifier: "expiry_date"),
        AttributeKey(namespace: standard, identifier: "birth_date"),
        AttributeKey(namespace: standard, identifier: "age_over_NN"),
        AttributeKey(namespace: standard, identifier: "birth_place"),
        AttributeKey(namespace: standard, identifier: "resident_address"),
        AttributeKey(namespace: standard, identifier: "resident_city"),
        AttributeKey(namespace: standard, identifier: "resident_postal_code"),
        AttributeKey(namespace: standard, identifier: "issue_date"),
        AttributeKey(namespace: standard, identifier: "issuing_authority"),
        AttributeKey(namespace: standard, identifier: "issuing_country"),
        AttributeKey(namespace: standard, identifier: "un_distinguishing_sign"),
        AttributeKey(namespace: standard, identifier: "driving_privileges"),
        AttributeKey(namespace: gb, identifier: "provisional_driving_privileges"),
        AttributeKey(namespace: gb, identifier: "welsh_licence")
    ]

    /// Fast `pair -> rank` lookup built from `displayOrder`.
    private static let orderIndexByKey: [AttributeKey: Int] = {
        Dictionary(uniqueKeysWithValues: displayOrder.enumerated().map { ($1, $0) })
    }()

    /// The slot index all `age_over_NN` attributes share.
    private static let ageOverOrderIndex: Int =
        orderIndexByKey[AttributeKey(namespace: standard, identifier: "age_over_NN")]
            ?? displayOrder.count

    /// The set of non-age `(namespace, identifier)` pairs with a GDS label.
    private static let knownKeys: Set<AttributeKey> = Set(
        displayOrder.filter { $0.identifier != "age_over_NN" }
    )

    // MARK: Document mapping

    /// The localised-string key for a document type's GDS-aligned name, or
    /// `nil` for an unsupported document type.
    public static func documentNameKey(for docType: DocType) -> String? {
        switch docType {
        case .mdl:
            return "mdlDocumentName"
        }
    }

    // Document Icon
    @MainActor
    public static func documentIcon(for docType: DocType) -> UIImage? {
        switch docType {
        case .mdl:
            return UIImage(named: "mDLDocumentIcon", in: .module, with: nil)
        }
    }

    // MARK: Ordering

    public static func ordered(_ attributes: [ConsentAttribute]) -> [ConsentAttribute] {
        attributes
            .enumerated()
            .sorted { isOrderedBefore($0, $1) }
            .map(\.element)
    }

    // MARK: - Private

    private static func isOrderedBefore(
        _ lhs: (offset: Int, element: ConsentAttribute),
        _ rhs: (offset: Int, element: ConsentAttribute)
    ) -> Bool {
        let lhsRank = orderIndex(namespace: lhs.element.namespace, identifier: lhs.element.identifier)
        let rhsRank = orderIndex(namespace: rhs.element.namespace, identifier: rhs.element.identifier)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        let lhsAge = parsedAgeOver(namespace: lhs.element.namespace, identifier: lhs.element.identifier) ?? Int.max
        let rhsAge = parsedAgeOver(namespace: rhs.element.namespace, identifier: rhs.element.identifier) ?? Int.max
        if lhsAge != rhsAge {
            return lhsAge < rhsAge
        }
        return lhs.offset < rhs.offset
    }

    /// The canonical order index for a `(namespace, identifier)` pair
    /// (`age_over_NN` shares one slot). Unmapped pairs sort last (all share this
    /// rank).
    private static func orderIndex(namespace: String, identifier: String) -> Int {
        if parsedAgeOver(namespace: namespace, identifier: identifier) != nil {
            return ageOverOrderIndex
        }
        return orderIndexByKey[AttributeKey(namespace: namespace, identifier: identifier)]
            ?? displayOrder.count
    }

    /// Parses the `NN` from an `age_over_NN` identifier in the standard
    /// namespace, or `nil` if it is not a standard-namespace age-over
    /// attestation. Age attestations are only defined in the standard namespace,
    /// so an `age_over_NN`-shaped identifier under any other namespace is treated
    /// as an unmapped pair.
    private static func parsedAgeOver(namespace: String, identifier: String) -> Int? {
        guard namespace == standard else { return nil }
        let prefix = "age_over_"
        guard identifier.hasPrefix(prefix) else { return nil }
        return Int(identifier.dropFirst(prefix.count))
    }
}
