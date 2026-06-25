import SharingCryptoService

/// Builds an ISO 18013-5 `DocRequest` from a session's `AttributeGroup`.
public struct DocRequestBuilder {

    public init() {
        // Empty init required to make struct public facing
    }

    /// Maps an `AttributeGroup` to a `DocRequest` with CBOR-encoded `ItemsRequestBytes` (Tag 24).
    public func build(from group: AttributeGroup) -> DocRequest {
        var nameSpaces: [NameSpace] = []

        if !group.mdlAttributes.isEmpty {
            let elements = group.mdlAttributes.map {
                DataElement(identifier: $0.attribute.identifier, intentToRetain: $0.intentToRetain)
            }
            nameSpaces.append(NameSpace(name: AttributeGroup.Namespace.standard.rawValue, elements: elements))
        }

        if !group.gbMdlAttributes.isEmpty {
            let elements = group.gbMdlAttributes.map {
                DataElement(identifier: $0.attribute.identifier, intentToRetain: $0.intentToRetain)
            }
            nameSpaces.append(NameSpace(name: AttributeGroup.Namespace.gb.rawValue, elements: elements))
        }

        let itemsRequest = ItemsRequest(docType: group.docType, nameSpaces: nameSpaces)
        let nameSpaceDescriptions = itemsRequest.nameSpaces.map { nameSpace in
            let elements = nameSpace.elements.map { "\($0.identifier): \($0.intentToRetain)" }.joined(separator: ", ")
            return "\(nameSpace.name) [\(elements)]"
        }.joined(separator: ", ")
        print("ItemsRequest built: docType=\(itemsRequest.docType.rawValue), nameSpaces={\(nameSpaceDescriptions)}")

        return DocRequest(itemsRequest: itemsRequest)
    }
}
