import Foundation
import SwiftCBOR

enum DeviceRequestError: Error {
    case deviceRequestWasIncorrectlyStructured
    case docRequestWasIncorrectlyStructured
    case itemsRequestWasIncorrectlyStructured
    case nameSpaceWasIncorrectlyStructured
    case unsupportedDocumentType
}

public struct DeviceRequest {
    let version: String
    let docRequests: [DocRequest]
    
    init(data: Data) throws {
        let decodedCBOR = try CBOR.decode([UInt8](data))

        guard case let .map(request) = decodedCBOR,
              case let .utf8String(version) = request[.version],
              case let .array(docRequests) = request[.docRequests]
        else {
            throw DeviceRequestError.deviceRequestWasIncorrectlyStructured
        }

        self.version = version
        self.docRequests = try docRequests.map(DocRequest.init)
    }
}

fileprivate extension CBOR {
    static var version: CBOR { "version" }
    static var docRequests: CBOR { "docRequests" }
}
