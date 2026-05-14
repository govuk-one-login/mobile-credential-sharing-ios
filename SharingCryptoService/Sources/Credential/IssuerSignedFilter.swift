import Foundation
import SwiftCBOR

public enum IssuerSignedFilterError: LocalizedError {
    case noMatchingNameSpaces
    case noMatchingAttributes
}

@MainActor
public struct IssuerSignedFilter {
    private static let ageOverPattern = /^age_over_(\d{2})$/

    public init() {
        // Empty init required to make struct public facing
    }

    public func filter(
        parsedCredential: ParsedRawCredential,
        requestedNameSpaces: [NameSpace]
    ) throws -> IssuerSigned {
        var filteredNameSpaces: [String: [IssuerSignedItem]] = [:]
        var hasMatchingNameSpace = false

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
                        retained.append(toIssuerSignedItem(resolved))
                    }
                } else {
                    // Exact match
                    if let item = credentialItems.first(where: { $0.elementIdentifier == element.identifier }) {
                        retained.append(toIssuerSignedItem(item))
                    }
                }
            }

            if !retained.isEmpty {
                filteredNameSpaces[requestedNS.name] = retained
            }
        }

        guard hasMatchingNameSpace else {
            throw IssuerSignedFilterError.noMatchingNameSpaces
        }

        guard !filteredNameSpaces.isEmpty else {
            throw IssuerSignedFilterError.noMatchingAttributes
        }

        return IssuerSigned(
            nameSpaces: filteredNameSpaces,
            issuerAuth: parsedCredential.issuerAuth
        )
    }

    // MARK: - Age_Over_NN Resolution

    func resolveAgeOver(requestedAge: Int, available: [IssuerSignedItemBytes]) -> IssuerSignedItemBytes? {
        // Step 1: Find closest TRUE where stored age >= requested
        let trueMatches = available.filter { item in
            guard let storedAge = extractAge(from: item.elementIdentifier),
                  item.elementValue == .boolean(true),
                  storedAge >= requestedAge else { return false }
            return true
        }
        if let closest = trueMatches.min(by: { extractAge(from: $0.elementIdentifier)! < extractAge(from: $1.elementIdentifier)! }) {
            return closest
        }

        // Step 2: Find closest FALSE where stored age <= requested
        let falseMatches = available.filter { item in
            guard let storedAge = extractAge(from: item.elementIdentifier),
                  item.elementValue == .boolean(false),
                  storedAge <= requestedAge else { return false }
            return true
        }
        if let closest = falseMatches.max(by: { extractAge(from: $0.elementIdentifier)! < extractAge(from: $1.elementIdentifier)! }) {
            return closest
        }

        return nil
    }

    private func extractAge(from identifier: String) -> Int? {
        guard let match = identifier.wholeMatch(of: Self.ageOverPattern) else { return nil }
        return Int(match.1)
    }

    private func toIssuerSignedItem(_ item: IssuerSignedItemBytes) -> IssuerSignedItem {
        IssuerSignedItem(rawCBOR: item.rawCBOR)
    }
}
