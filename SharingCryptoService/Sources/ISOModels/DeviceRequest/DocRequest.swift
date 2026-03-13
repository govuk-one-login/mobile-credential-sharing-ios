import SwiftCBOR

public struct DocRequest: Equatable, Hashable, Sendable {
    public let itemsRequest: ItemsRequest
    
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
    }
}

fileprivate extension CBOR {
    static var itemsRequest: CBOR { "itemsRequest" }
    static var readerAuth: CBOR { "readerAuth" }
}
