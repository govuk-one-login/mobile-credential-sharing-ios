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
        var filteredNameSpaces: [String: [IssuerSignedItem]] = [:]
        var mergedRetention: [String: [String: Bool]] = [:]
        var hasMatchingNameSpace = false

        // Validate total age_over_NN request count (max 2 across all namespaces)
        let totalAgeOverCount = requestedNameSpaces.flatMap(\.elements).filter {
            $0.identifier.wholeMatch(of: Self.ageOverPattern) != nil
        }.count
        guard totalAgeOverCount <= 2 else {
            throw IssuerSignedFilterError.exceededAgeOverLimit
        }
        
        // Policy violation — portrait must be requested
        let portraitRequested = requestedNameSpaces.flatMap(\.elements)
            .contains { $0.identifier == Self.portraitIdentifier }
        guard portraitRequested else {
            throw IssuerSignedFilterError.portraitNotRequested
        }

        for requestedNS in requestedNameSpaces {
            guard let credentialItems = parsedCredential.nameSpaces[requestedNS.name] else {
                continue
            }
            hasMatchingNameSpace = true

            var retained: [IssuerSignedItem] = []

            // Collect age_over items from credential for nearest-match logic
            let ageOverItems = credentialItems.filter {
                $0.elementIdentifier.wholeMatch(of: Self.ageOverPattern) != nil
            }

            for element in requestedNS.elements {
                if let match = element.identifier.wholeMatch(of: Self.ageOverPattern) {
                    // age_over_NN request - use nearest-match logic
                    // force unwrapping the Int here is safe as the if let ensures a 2 digit number is returned
                    let requestedAge = Int(match.1)!
                    if let resolved = resolveAgeOver(requestedAge: requestedAge, available: ageOverItems) {
                        retained.append(try toIssuerSignedItem(resolved))
                        mergeRetention(
                            &mergedRetention,
                            nameSpace: requestedNS.name,
                            resolvedIdentifier: resolved.elementIdentifier,
                            intentToRetain: element.intentToRetain
                        )
                    }
                } else {
                    // Exact match
                    if let item = credentialItems.first(where: { $0.elementIdentifier == element.identifier }) {
                        retained.append(try toIssuerSignedItem(item))
                        mergeRetention(
                            &mergedRetention,
                            nameSpace: requestedNS.name,
                            resolvedIdentifier: item.elementIdentifier,
                            intentToRetain: element.intentToRetain
                        )
                    }
                }
            }

            let deduplicated = deduplicateByIdentifier(retained)
            if !deduplicated.isEmpty {
                filteredNameSpaces[requestedNS.name] = deduplicated
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

    // MARK: - intentToRetain Merge

    /// Merges the request-side `intentToRetain` flag onto a resolved element
    /// using a most-restrictive (logical OR ||) rule: when distinct
    /// requests resolve to the same element, the merged flag is `true` if *any*
    /// contributing request asked to retain. Keyed by namespace then resolved
    /// element identifier so it aligns with the de-duplicated `IssuerSigned`.
    private func mergeRetention(
        _ retention: inout [String: [String: Bool]],
        nameSpace: String,
        resolvedIdentifier: String,
        intentToRetain: Bool
    ) {
        let alreadyRetained = retention[nameSpace]?[resolvedIdentifier] ?? false
        let mergedIntentToRetain = alreadyRetained || intentToRetain
        retention[nameSpace, default: [:]][resolvedIdentifier] = mergedIntentToRetain
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
