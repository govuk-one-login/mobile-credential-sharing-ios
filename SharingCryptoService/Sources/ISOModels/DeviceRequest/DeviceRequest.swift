import Foundation
import SwiftCBOR

public struct DeviceRequest: Sendable, Equatable, Hashable {
    public let version: String
    public let docRequests: [DocRequest]
    
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
