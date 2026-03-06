import SwiftCBOR

struct DocRequest {
    let itemsRequest: ItemsRequest
    
    init(cbor: CBOR) throws {
        guard case let .map(request) = cbor,
              case .tagged(.encodedCBORDataItem, .byteString(let encodedItem)) = request[.itemsRequest],
              let itemsRequest = try CBOR.decode(encodedItem) else {
            throw DeviceRequestError.docRequestWasIncorrectlyStructured
        }
        self.itemsRequest = try ItemsRequest(cbor: itemsRequest)
        
    }
}

fileprivate extension CBOR {
    static var itemsRequest: CBOR { "itemsRequest" }
}
