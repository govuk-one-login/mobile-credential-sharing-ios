import SharingLogging
import SwiftCBOR

public struct DocRequest: Equatable, Hashable, Sendable {
    public let itemsRequest: ItemsRequest
    /// Optional reader authentication data. Not populated in MVP.
    public let readerAuth: [UInt8]?

    /// The exact Tag-24 `ItemsRequest` bytes to transmit, when they must match a value signed
    /// elsewhere (ReaderAuth). When set, `toCBOR` emits these bytes verbatim instead of re-encoding
    /// `itemsRequest`, so the transmitted `itemsRequest` is byte-identical to the signed payload.
    public let itemsRequestBytes: [UInt8]?

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
        self.itemsRequestBytes = nil
    }
    
    /// Creates a `DocRequest` from an existing `ItemsRequest` and optional ReaderAuth `COSE_Sign1`.
    /// - Parameter itemsRequestBytes: The exact Tag-24 `ItemsRequest` bytes signed by ReaderAuth,
    ///   transmitted verbatim so the holder reconstructs the identical signed payload.
    public init(itemsRequest: ItemsRequest, readerAuth: [UInt8]?, itemsRequestBytes: [UInt8]? = nil) {
        self.itemsRequest = itemsRequest
        self.readerAuth = readerAuth
        self.itemsRequestBytes = itemsRequestBytes
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
        self.itemsRequestBytes = nil
    }
}

extension DocRequest: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        let itemsRequestValue: CBOR
        if let itemsRequestBytes, let preserved = try? CBOR.decode(itemsRequestBytes) {
            // Emit the exact signed bytes verbatim (byte-preserving round-trip).
            itemsRequestValue = preserved
        } else {
            itemsRequestValue = itemsRequest.asDataItem(options: options)
        }

        var map: [CBOR: CBOR] = [
            .itemsRequest: itemsRequestValue
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
