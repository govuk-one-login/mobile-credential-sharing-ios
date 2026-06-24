import SwiftCBOR

public struct DocRequest: Equatable, Hashable, Sendable {
    public let itemsRequest: ItemsRequest
    /// Optional reader authentication data. Not populated in MVP.
    public let readerAuth: [UInt8]?

    public init(itemsRequest: ItemsRequest, readerAuth: [UInt8]? = nil) {
        self.itemsRequest = itemsRequest
        self.readerAuth = readerAuth
    }

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
