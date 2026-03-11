import Foundation
import SwiftCBOR

enum DeviceRequestError: LocalizedError {
    case dataIsNotValidCBOR
    case deviceRequestWasIncorrectlyStructured
    case docRequestWasEmpty
    case docRequestWasIncorrectlyStructured
    case itemsRequestWasIncorrectlyStructured
    case nameSpaceWasIncorrectlyStructured
    case unsupportedDocumentType
    
    var errorDescription: String? {
        switch self {
        case .dataIsNotValidCBOR:
            return "CBOR decoding error: status code 11"
        default:
            return "\(self): status code 20"
        }
    }
}

public struct DeviceRequest {
    let version: String
    let docRequests: [DocRequest]
    
    public init(data: Data) throws {
        do {
            let decodedCBOR = try CBOR.decode([UInt8](data))
        
            guard case let .map(request) = decodedCBOR,
                  case let .utf8String(version) = request[.version],
                  case let .array(docRequests) = request[.docRequests]
            else {
                throw DeviceRequestError.deviceRequestWasIncorrectlyStructured
            }
            
            guard !docRequests.isEmpty else {
                throw DeviceRequestError.docRequestWasEmpty
            }

            self.version = version
            self.docRequests = try docRequests.map(DocRequest.init)
        } catch _ as CBORError {
            throw DeviceRequestError.dataIsNotValidCBOR
        }
    }
}

fileprivate extension CBOR {
    static var version: CBOR { "version" }
    static var docRequests: CBOR { "docRequests" }
}
