import SharingCryptoService

/// Builds an ISO 18013-5 `DocRequest` from a session's `AttributeGroup`.
public struct DocRequestBuilder {

    public init() {}

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
        print("ItemsRequest built: docType-\(itemsRequest.docType.rawValue), nameSpaces-\(itemsRequest.nameSpaces.map { $0.name })")

        return DocRequest(itemsRequest: itemsRequest)
    }
}
