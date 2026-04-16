import Foundation
import SwiftCBOR

public enum DeviceResponseStatus: UInt64, Equatable, Sendable {
    case ok = 0
    case generalError = 10
    case cborDecodingError = 11
    case cborValidationError = 12
}

public struct DeviceResponse: Equatable, Hashable, Sendable {
    public let version: String
    public let documents: [Document]?
    public let documentErrors: [DocumentError]?
    public let status: DeviceResponseStatus
    
    public init(
        version: String = "1.0",
        documents: [Document]?,
        documentErrors: [DocumentError]? = nil,
        status: DeviceResponseStatus = .ok
    ) {
        self.version = version
        self.documents = documents
        self.documentErrors = documentErrors
        self.status = status
    }
}

extension DeviceResponse: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [
            .version: .utf8String(version),
            .status: .unsignedInt(status.rawValue)
        ]
        
        if let documents = documents {
            map[.documents] = .array(documents.map { $0.toCBOR(options: options) })
        }
        
        if let documentErrors = documentErrors {
            map[.documentErrors] = .array(documentErrors.map { $0.toCBOR(options: options) })
        }
        
        return .map(map)
    }
}

fileprivate extension CBOR {
    static var version: CBOR { "version" }
    static var documents: CBOR { "documents" }
    static var documentErrors: CBOR { "documentErrors" }
    static var status: CBOR { "status" }
}
