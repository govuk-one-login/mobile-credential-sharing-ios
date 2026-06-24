import SwiftCBOR

public struct ItemsRequest: Equatable, Hashable, Sendable {
    public let docType: DocType
    public let nameSpaces: [NameSpace]

    public init(docType: DocType, nameSpaces: [NameSpace]) {
        self.docType = docType
        self.nameSpaces = nameSpaces
    }

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

extension ItemsRequest: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var nameSpacesMap: [CBOR: CBOR] = [:]
        for nameSpace in nameSpaces {
            nameSpacesMap[.utf8String(nameSpace.name)] = nameSpace.toCBOR(options: options)
        }
        return .map([
            .docType: .utf8String(docType.rawValue),
            .nameSpaces: .map(nameSpacesMap)
        ])
    }
}

fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var nameSpaces: CBOR { "nameSpaces" }
}
