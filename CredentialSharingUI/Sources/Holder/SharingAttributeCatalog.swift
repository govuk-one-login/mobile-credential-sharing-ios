import DesignSystem
import Foundation
import SharingCryptoService
import UIKit

// MARK: - SharingCardAttribute

/// A single requested data element as needed by the "Agree to Share" card.
/// This is the raw, pre-mapping input: the ISO namespace, the data element
/// identifier (e.g. `family_name`, `age_over_18`) and whether the verifier
/// intends to retain it. The GDS-aligned display label and ordering are derived
/// by ``SharingAttributeCatalog``.
public struct SharingCardAttribute: Equatable, Hashable, Sendable {
    public let namespace: String
    public let identifier: String
    public let intentToRetain: Bool

    public init(namespace: String, identifier: String, intentToRetain: Bool) {
        self.namespace = namespace
        self.identifier = identifier
        self.intentToRetain = intentToRetain
    }
}

// MARK: - SharingAttributeCatalog

/// GDS-aligned mapping, ordering and iconography for the "Agree to Share" card.
public enum SharingAttributeCatalog {

    // MARK: Order table

    /// The design-defined display order. `age_over_NN` is represented by the
    /// `age_over_NN` sentinel so the surrounding attributes keep their slots.
    private static let canonicalOrder: [String] = [
        "document_number",
        "portrait",
        "title",
        "family_name",
        "given_name",
        "expiry_date",
        "birth_date",
        "age_over_NN",
        "birth_place",
        "resident_address",
        "resident_city",
        "resident_postal_code",
        "issue_date",
        "issuing_authority",
        "issuing_country",
        "un_distinguishing_sign",
        "driving_privileges",
        "provisional_driving_privileges",
        "welsh_licence"
    ]

    /// The slot index all `age_over_NN` attributes share.
    private static let ageOverOrderIndex: Int = {
        canonicalOrder.firstIndex(of: "age_over_NN") ?? canonicalOrder.count
    }()

    /// The set of non-age identifiers with a GDS label.
    private static let knownIdentifiers: Set<String> = Set(
        canonicalOrder.filter { $0 != "age_over_NN" }
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
                ?? SharingCardRowViewModel.documentImage()
        }
    }

    // MARK: Attribute label mapping

    /// ``labelVariableKeys(namespace:identifier:)``).
    public static func attributeLabelKey(namespace: String, identifier: String) -> String? {
        if parsedAgeOver(from: identifier) != nil {
            return "attr.age_over_NN"
        }
        guard knownIdentifiers.contains(identifier) else { return nil }
        return "attr.\(identifier)"
    }

    /// The format arguments for an attribute label. Only `age_over_NN` carries
    /// one (the `NN` value); everything else is argument-free.
    public static func labelVariableKeys(namespace: String, identifier: String) -> [String] {
        guard let age = parsedAgeOver(from: identifier) else { return [] }
        return ["\(age)"]
    }

    // MARK: Ordering

    /// Returns the attributes in the canonical GDS display order.
    ///
    /// Recognised attributes are ordered by the design-defined table. Repeated
    /// `age_over_NN` attestations occupy the single `age_over` slot ordered from
    /// lowest to highest `NN`. Unmapped attributes are kept (rendered later
    /// using their raw identifier) and sorted to the bottom of the list,
    /// preserving their incoming relative order.
    public static func ordered(_ attributes: [SharingCardAttribute]) -> [SharingCardAttribute] {
        // `enumerated` gives a stable tie-break so unmapped attributes (which
        // all share the "sort last" rank) keep their incoming order.
        attributes
            .enumerated()
            .sorted { isOrderedBefore($0, $1) }
            .map(\.element)
    }

    // MARK: - Private

    /// Primary sort by canonical rank; ties broken by `age_over_NN` ascending,
    /// then by incoming index to keep the sort stable (notably for the
    /// equally-ranked unmapped attributes).
    private static func isOrderedBefore(
        _ lhs: (offset: Int, element: SharingCardAttribute),
        _ rhs: (offset: Int, element: SharingCardAttribute)
    ) -> Bool {
        let lhsRank = orderIndex(for: lhs.element.identifier)
        let rhsRank = orderIndex(for: rhs.element.identifier)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        let lhsAge = parsedAgeOver(from: lhs.element.identifier) ?? Int.max
        let rhsAge = parsedAgeOver(from: rhs.element.identifier) ?? Int.max
        if lhsAge != rhsAge {
            return lhsAge < rhsAge
        }
        return lhs.offset < rhs.offset
    }

    /// The canonical order index for an identifier (`age_over_NN` shares one
    /// slot). Unmapped identifiers sort last (all share this rank).
    private static func orderIndex(for identifier: String) -> Int {
        if parsedAgeOver(from: identifier) != nil {
            return ageOverOrderIndex
        }
        return canonicalOrder.firstIndex(of: identifier) ?? canonicalOrder.count
    }

    /// Parses the `NN` from an `age_over_NN` identifier, or `nil` if it is not
    /// an age-over attestation.
    private static func parsedAgeOver(from identifier: String) -> Int? {
        let prefix = "age_over_"
        guard identifier.hasPrefix(prefix) else { return nil }
        return Int(identifier.dropFirst(prefix.count))
    }
}
