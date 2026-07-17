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
        status: DeviceResponseStatus
    ) {
        self.version = version
        self.documents = documents
        self.documentErrors = documentErrors
        self.status = status
    }

    /// Decodes a `DeviceResponse` from raw CBOR-encoded data.
    public init(data: Data) throws {
        // Reject null or empty input before CBOR decoding
        guard !data.isEmpty else {
            throw DeviceResponseError.invalidInput
        }

        // Reject malformed CBOR
        let decodedCBOR: CBOR
        do {
            guard let decoded = try CBOR.decode([UInt8](data)) else {
                throw DeviceResponseError.cborDecodingError
            }
            decodedCBOR = decoded
        } catch {
            throw DeviceResponseError.cborDecodingError
        }

        guard case let .map(responseMap) = decodedCBOR,
              case let .utf8String(version) = responseMap[.version],
              case let .unsignedInt(statusRaw) = responseMap[.status]
        else {
            throw DeviceResponseError.cborDecodingError
        }

        guard let status = DeviceResponseStatus(rawValue: statusRaw) else {
            throw DeviceResponseError.cborDecodingError
        }

        // Handle DeviceRequest processing error (status 10, 11, or 12)
        switch status {
        case .generalError, .cborDecodingError, .cborValidationError:
            print("DeviceRequest processing error: status code \(statusRaw)")
            throw DeviceResponseError.deviceRequestProcessingError(status: statusRaw)
        case .ok:
            break
        }

        // Handle Document Not Returned error (status 0 with no documents)
        guard case let .array(documentsArray) = responseMap[.documents],
              !documentsArray.isEmpty else {
            print("Document not returned error: status code 0")
            throw DeviceResponseError.documentNotReturned
        }

        // Process single/multiple documents; halt on malformed entries
        let documents: [Document] = try documentsArray.map { documentCBOR in
            do {
                return try Document(cbor: documentCBOR)
            } catch {
                throw DeviceResponseError.cborDecodingError
            }
        }

        // Unsupported optional fields (documentErrors, zkDocuments, deviceSigned namespaces)
        // are simply not extracted — no error is thrown for their presence.

        self.version = version
        self.status = status
        self.documents = documents
        self.documentErrors = nil
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
