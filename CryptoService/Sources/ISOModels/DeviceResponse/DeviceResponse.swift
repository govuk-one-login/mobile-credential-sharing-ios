import Foundation
import SwiftCBOR

public struct DeviceResponse {
    let version: String
    let documents: [Document]?
    let documentErrors: [DocumentError]?
    let status: UInt
    
    public init(
        version: String = "1.0",
        documents: [Document]?,
        documentErrors: [DocumentError]? = nil,
        status: UInt = 0
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
            .status: .unsignedInt(status)
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
