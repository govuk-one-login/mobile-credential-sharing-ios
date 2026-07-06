import SharingCryptoService
import SharingValidationService

public enum DCQLMappingError: Error, Equatable, Sendable {
    case missingDoctype
    case unsupportedDoctype(String)
    case invalidClaimPath([String])
    case noClaims
}

/// Maps a DCQL `CredentialQuery` (mso_mdoc format) to an ISO 18013-5 `ItemsRequest`, the requested
/// attribute set consumed by `IssuerSignedFilter`. The provider-side counterpart to the verifier's
/// `DocRequestBuilder`.
public struct DCQLMapper {
    public init() {
        // Empty init required to make struct public facing
    }

    public func mapToItemsRequest(_ credential: CredentialQuery) throws -> ItemsRequest {
        guard let doctypeValue = credential.meta?.doctypeValue else {
            throw DCQLMappingError.missingDoctype
        }

        guard let docType = DocType(rawValue: doctypeValue) else {
            throw DCQLMappingError.unsupportedDoctype(doctypeValue)
        }

        guard let claims = credential.claims, !claims.isEmpty else {
            throw DCQLMappingError.noClaims
        }

        return ItemsRequest(docType: docType, nameSpaces: try nameSpaces(from: claims))
    }

    /// Groups claims by namespace (`path[0]`), preserving first-seen order, with each element
    /// identifier (`path[1]`) carrying its `intent_to_retain` flag.
    private func nameSpaces(from claims: [ClaimQuery]) throws -> [NameSpace] {
        var order: [String] = []
        var elementsByNameSpace: [String: [DataElement]] = [:]

        for claim in claims {
            guard claim.path.count == 2 else {
                throw DCQLMappingError.invalidClaimPath(claim.path)
            }
            let namespace = claim.path[0]
            let element = DataElement(identifier: claim.path[1], intentToRetain: claim.intentToRetain)

            if elementsByNameSpace[namespace] == nil {
                order.append(namespace)
            }
            elementsByNameSpace[namespace, default: []].append(element)
        }

        return order.map { NameSpace(name: $0, elements: elementsByNameSpace[$0] ?? []) }
    }
}
