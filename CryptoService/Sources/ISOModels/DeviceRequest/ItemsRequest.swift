import SwiftCBOR

struct ItemsRequest {
    let documentType: DocumentType
    let nameSpaces: [NameSpace]
    
    init(cbor: CBOR) throws {
        guard case .map(let request) = cbor,
              case .utf8String(let docType) = request[.docType],
              case .map(let nameSpaces) = request[.nameSpaces]
        else {
            throw DeviceRequestError.itemsRequestWasIncorrectlyStructured
        }
        
        guard let documentType = DocumentType(rawValue: docType) else {
            throw DeviceRequestError.unsupportedDocumentType
        }
        self.documentType = documentType
        self.nameSpaces = try nameSpaces.map {
            guard case .utf8String(let name) = $0 else {
                throw DeviceRequestError.itemsRequestWasIncorrectlyStructured
            }
            return try NameSpace(name: name, cbor: $1)
        }
    }
}

fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var nameSpaces: CBOR { "nameSpaces" }
}
