import Foundation
import SwiftCBOR

public enum IssuerSignedFilterError: LocalizedError {
    case noMatchingNameSpaces
    case noMatchingAttributes
    case exceededAgeOverLimit
    case portraitNotRequested
    
    public var errorDescription: String? {
        switch self {
        case .noMatchingNameSpaces:
            "SessionData termination initiated due to no matching NameSpaces"
        case .noMatchingAttributes:
            "SessionData termination initiated due to no matching attributes"
        case .exceededAgeOverLimit:
            "SessionData termination initiated due to exceeding age_over_NN request limit"
        case .portraitNotRequested:
            "SessionData termination initiated due to portrait not being requested"
        }
    }
}

/// The output of ``IssuerSignedFilter/filter(parsedCredential:requestedNameSpaces:)``.
///
/// `issuerSigned` is the ISO wire model destined for the `DeviceResponse`.
/// `retention` carries the merged `intentToRetain` flags keyed by namespace then
/// resolved element identifier — a request-side concept that has no place on the
/// wire model — for downstream consumers (e.g. the consent screen).
public struct FilterResult: Equatable, Sendable {
    public let issuerSigned: IssuerSigned
    public let retention: [String: [String: Bool]]

    public init(issuerSigned: IssuerSigned, retention: [String: [String: Bool]]) {
        self.issuerSigned = issuerSigned
        self.retention = retention
    }
}

@MainActor
public struct IssuerSignedFilter {
    private static let ageOverPattern = /^age_over_(\d{2})$/
    private static let portraitIdentifier = "portrait"

    public init() {
        // Empty init required to make struct public facing
    }

    public func filter(
        parsedCredential: ParsedRawCredential,
        requestedNameSpaces: [NameSpace]
    ) throws -> FilterResult {
        try validateRequest(requestedNameSpaces)

        var filteredNameSpaces: [String: [IssuerSignedItem]] = [:]
        var mergedRetention: [String: [String: Bool]] = [:]
        var hasMatchingNameSpace = false

        for requestedNS in requestedNameSpaces {
            guard let credentialItems = parsedCredential.nameSpaces[requestedNS.name] else {
                continue
            }
            hasMatchingNameSpace = true

            let resolved = try resolveNameSpace(requestedNS, against: credentialItems)

            let deduplicated = deduplicateByIdentifier(resolved.items)
            if !deduplicated.isEmpty {
                filteredNameSpaces[requestedNS.name] = deduplicated
                mergedRetention[requestedNS.name] = resolved.retention
            }
        }

        guard hasMatchingNameSpace else {
            throw IssuerSignedFilterError.noMatchingNameSpaces
        }

        guard !filteredNameSpaces.isEmpty else {
            throw IssuerSignedFilterError.noMatchingAttributes
        }

        return FilterResult(
            issuerSigned: IssuerSigned(
                nameSpaces: filteredNameSpaces,
                issuerAuth: parsedCredential.issuerAuth
            ),
            retention: mergedRetention
        )
    }

    // MARK: - Request Validation

    /// Validates request-level policies that apply across all namespaces before
    /// any filtering: at most two `age_over_NN` elements may be requested, and a
    /// portrait must always be requested.
    private func validateRequest(_ requestedNameSpaces: [NameSpace]) throws {
        let allElements = requestedNameSpaces.flatMap(\.elements)

        let totalAgeOverCount = allElements.filter {
            $0.identifier.wholeMatch(of: Self.ageOverPattern) != nil
        }.count
        guard totalAgeOverCount <= 2 else {
            throw IssuerSignedFilterError.exceededAgeOverLimit
        }

        let portraitRequested = allElements.contains { $0.identifier == Self.portraitIdentifier }
        guard portraitRequested else {
            throw IssuerSignedFilterError.portraitNotRequested
        }
    }

    // MARK: - NameSpace Resolution

    /// Resolves a single requested namespace against the credential's items for
    /// that namespace, returning the retained items (pre-de-duplication) alongside
    /// the merged `intentToRetain` flags keyed by resolved element identifier.
    private func resolveNameSpace(
        _ requestedNS: NameSpace,
        against credentialItems: [IssuerSignedItemBytes]
    ) throws -> (items: [IssuerSignedItem], retention: [String: Bool]) {
        var retained: [IssuerSignedItem] = []
        var retention: [String: Bool] = [:]

        // Collect age_over items from credential for nearest-match logic
        let ageOverItems = credentialItems.filter {
            $0.elementIdentifier.wholeMatch(of: Self.ageOverPattern) != nil
        }

        for element in requestedNS.elements {
            guard let resolvedItem = resolveElement(element, credentialItems: credentialItems, ageOverItems: ageOverItems) else {
                continue
            }
            retained.append(try toIssuerSignedItem(resolvedItem))
            mergeRetention(
                &retention,
                resolvedIdentifier: resolvedItem.elementIdentifier,
                intentToRetain: element.intentToRetain
            )
        }

        return (retained, retention)
    }

    /// Resolves a single requested element to a credential item: `age_over_NN`
    /// requests use nearest-match logic; all other identifiers use an exact match.
    /// Returns `nil` when nothing in the credential satisfies the request.
    private func resolveElement(
        _ element: DataElement,
        credentialItems: [IssuerSignedItemBytes],
        ageOverItems: [IssuerSignedItemBytes]
    ) -> IssuerSignedItemBytes? {
        if let match = element.identifier.wholeMatch(of: Self.ageOverPattern) {
            // force unwrapping the Int here is safe as the wholeMatch ensures a 2 digit number is returned
            let requestedAge = Int(match.1)!
            return resolveAgeOver(requestedAge: requestedAge, available: ageOverItems)
        }
        return credentialItems.first { $0.elementIdentifier == element.identifier }
    }

    // MARK: - intentToRetain Merge

    /// Merges the request-side `intentToRetain` flag onto a resolved element
    /// using a most-restrictive (logical OR ||) rule: when distinct
    /// requests resolve to the same element, the merged flag is `true` if *any*
    /// contributing request asked to retain. Keyed by resolved element identifier
    /// so it aligns with the de-duplicated `IssuerSigned` for the namespace.
    private func mergeRetention(
        _ retention: inout [String: Bool],
        resolvedIdentifier: String,
        intentToRetain: Bool
    ) {
        let alreadyRetained = retention[resolvedIdentifier] ?? false
        let mergedIntentToRetain = alreadyRetained || intentToRetain
        retention[resolvedIdentifier] = mergedIntentToRetain
    }

    // MARK: - De-duplication

    /// Removes items sharing an `elementIdentifier`, keeping the first occurrence
    /// and preserving order. Distinct age_over_NN requests can
    /// resolve to the same credential attestation (e.g. age_over_16 and
    /// age_over_17 both resolving to age_over_18); this runs as the step after
    /// nearest-match resolution so each resolved element appears at most once.
    private func deduplicateByIdentifier(_ items: [IssuerSignedItem]) -> [IssuerSignedItem] {
        var seenIdentifiers = Set<String>()
        return items.filter {
            seenIdentifiers.insert($0.elementIdentifier).inserted
        }
    }

    // MARK: - Age_Over_NN Resolution

    func resolveAgeOver(requestedAge: Int, available: [IssuerSignedItemBytes]) -> IssuerSignedItemBytes? {
        // Step 1: Find closest TRUE where stored age >= requested
        let trueMatches = available.compactMap { item -> (age: Int, item: IssuerSignedItemBytes)? in
            guard let storedAge = extractAge(from: item.elementIdentifier),
                  item.elementValue == .boolean(true),
                  storedAge >= requestedAge else {
                return nil
            }
            return (storedAge, item)
        }
        if let closest = trueMatches.min(by: { $0.age < $1.age }) {
            return closest.item
        }

        // Step 2: Find closest FALSE where stored age <= requested
        let falseMatches = available.compactMap { item -> (age: Int, item: IssuerSignedItemBytes)? in
            guard let storedAge = extractAge(from: item.elementIdentifier),
                  item.elementValue == .boolean(false),
                  storedAge <= requestedAge else { return nil }
            return (storedAge, item)
        }
        if let closest = falseMatches.max(by: { $0.age < $1.age }) {
            return closest.item
        }

        return nil
    }

    private func extractAge(from identifier: String) -> Int? {
        guard let match = identifier.wholeMatch(of: Self.ageOverPattern) else { return nil }
        return Int(match.1)
    }

    private func toIssuerSignedItem(_ item: IssuerSignedItemBytes) throws -> IssuerSignedItem {
        try IssuerSignedItem(rawCBOR: item.rawCBOR)
    }
}
