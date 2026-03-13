import SwiftCBOR

public struct ItemsRequest: Equatable, Hashable, Sendable {
    public let docType: DocType
    public let nameSpaces: [NameSpace]
    
    init(cbor: CBOR) throws {
        guard case .map(let request) = cbor,
              case .utf8String(let rawDocType) = request[.docType],
              case .map(let nameSpaces) = request[.nameSpaces]
        else {
            throw DeviceRequestError.itemsRequestWasIncorrectlyStructured
        }
        
        guard let docType = DocType(rawValue: rawDocType) else {
            throw DeviceRequestError.unsupportedDocumentType
        }
        self.docType = docType
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
