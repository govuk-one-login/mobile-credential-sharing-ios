import SharingLogging
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
            Logger.log("Optional 'readerAuth' field was present, but ignored")
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
        // Note: requested namespaces/attribute identifiers reveal what is being requested about the
        // holder; log docType and counts only, not the element identifiers.
        let elementCount = itemsRequest.nameSpaces.reduce(0) { $0 + $1.elements.count }
        Logger.log("ItemsRequest built: docType=\(itemsRequest.docType.rawValue), nameSpaces=\(itemsRequest.nameSpaces.count), elements=\(elementCount)")

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
