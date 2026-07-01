import SwiftCBOR

public struct DocRequest: Equatable, Hashable, Sendable {
    public let itemsRequest: ItemsRequest
    /// Optional reader authentication data. Not populated in MVP.
    public let readerAuth: [UInt8]?

    init(cbor: CBOR) throws {
        guard case let .map(request) = cbor,
              case .tagged(.encodedCBORDataItem, .byteString(let encodedItem)) = request[.itemsRequest],
              let itemsRequest = try CBOR.decode(encodedItem) else {
            throw DeviceRequestError.docRequestWasIncorrectlyStructured
        }
        if request[.readerAuth] != nil {
            print("Optional 'readerAuth' field was present, but ignored")
        }
        self.itemsRequest = try ItemsRequest(cbor: itemsRequest)
        self.readerAuth = nil
    }
    
    public init(with group: AttributeGroup) {
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

        self.itemsRequest = itemsRequest
        self.readerAuth = nil
    }
}

extension DocRequest: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [
            .itemsRequest: itemsRequest.asDataItem(options: options)
        ]
        if let readerAuth {
            map[.readerAuth] = .byteString(readerAuth)
        }
        return .map(map)
    }
}

fileprivate extension CBOR {
    static var itemsRequest: CBOR { "itemsRequest" }
    static var readerAuth: CBOR { "readerAuth" }
}
