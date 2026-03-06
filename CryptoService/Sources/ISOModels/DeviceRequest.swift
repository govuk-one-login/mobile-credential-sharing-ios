import Foundation
import SwiftCBOR

public struct DeviceRequest {
    let version: String
    let docRequests: [DocRequest]
    
    init(data: Data) throws {
        let decodedCBOR = try CBOR.decode([UInt8](data))

        guard case let .map(request) = decodedCBOR,
              case let .utf8String(version) = request[.version],
              case let .array(docRequests) = request[.docRequests]
        else {
            fatalError()
//            throw DeviceRequestError.requestWasIncorrectlyStructured
        }

        self.version = version
        self.docRequests = try docRequests.map(DocRequest.init)
    }
    
    
}

fileprivate extension CBOR {
    static var version: CBOR { "version" }
    static var docRequests: CBOR { "docRequests" }
}

struct DocRequest {
    let itemsRequest: ItemsRequest
    
    init(cbor: CBOR) throws {
        guard case let .map(request) = cbor,
              case .tagged(.encodedCBORDataItem, .byteString(let encodedItem)) = request[.itemsRequest],
              let itemsRequest = try CBOR.decode(encodedItem) else {
            fatalError()
        }
        self.itemsRequest = try ItemsRequest(cbor: itemsRequest)
        
    }
}
fileprivate extension CBOR {
    static var itemsRequest: CBOR { "itemsRequest" }
}


struct ItemsRequest {
    let documentType: DocumentType
    let nameSpaces: [NameSpace]
    
    init(cbor: CBOR) throws {
        guard case .map(let request) = cbor,
              case .utf8String(let docType) = request[.docType],
              case .map(let nameSpaces) = request[.nameSpaces]
        else {
            fatalError()
        }
        
        guard let documentType = DocumentType(rawValue: docType) else {
//            throw DeviceRequestError.unsupportedDocumentType
            fatalError()
        }
        self.documentType = documentType
        self.nameSpaces = try nameSpaces.map {
            guard case .utf8String(let name) = $0 else {
//                throw DeviceRequestError.requestWasIncorrectlyStructured
                fatalError()
            }
            return try NameSpace(name: name, cbor: $1)
        }
    }
}
fileprivate extension CBOR {
    static var docType: CBOR { "docType" }
    static var nameSpaces: CBOR { "nameSpaces" }
}

struct DocType {}

struct NameSpace: Equatable {
    let name: String
    let elements: [DataElement]
    
    init(name: String, cbor: CBOR) throws {
        self.name = name

        guard case let .map(elements) = cbor else {
//            throw DeviceRequestError.requestWasIncorrectlyStructured
            fatalError()
        }

        self.elements = elements.map {
            guard case .utf8String(let element) = $0,
                  case .boolean(let intentToRetain) = $1
            else {
//                throw DeviceRequestError.requestWasIncorrectlyStructured
                fatalError()
            }

            return DataElement(identifier: element, intentToRetain: intentToRetain)
        }
    }
}

struct DataElement: Equatable {
    let identifier: String
    let intentToRetain: Bool
}

public enum DocumentType: String {
    case mdl = "org.iso.18013.5.1.mDL"
}
