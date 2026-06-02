import Foundation
import SwiftCBOR

public enum SessionEstablishmentError: LocalizedError {
    case cborMapMissing
    case cborEReaderKeyFieldMissing
    case cborDataFieldMissing
    
    public var errorDescription: String? {
        switch self {
        case .cborMapMissing:
            return "CBOR decoding error: SessionEstablishment contains invalid CBOR encoding (status code 11 CBOR decoding error)"
        case .cborEReaderKeyFieldMissing:
            return "CBOR parsing error: SessionEstablishment missing mandatory key 'eReaderKey' (status code 12 CBOR validation error)"
        case .cborDataFieldMissing:
            return "CBOR parsing error: SessionEstablishment missing mandatory key 'data' (status code 12 CBOR validation error)"
        }
    }
}

public struct SessionEstablishment {
    public let eReaderKeyBytes: [UInt8]
    public let eReaderKey: EReaderKey
    public let data: [UInt8]
    
    public init(rawData: Data) throws {
        let decodedCBOR = try CBOR.decode([UInt8](rawData))

        guard case let .map(request) = decodedCBOR else {
            throw SessionEstablishmentError.cborMapMissing
        }
        guard case let .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)) = request[.eReaderKey],
        let keyData = try CBOR.decode(eReaderKeyBytes) else {
            throw SessionEstablishmentError.cborEReaderKeyFieldMissing
        }
        guard case let .byteString(data) = request[.data] else {
            throw SessionEstablishmentError.cborDataFieldMissing
        }
        self.eReaderKeyBytes = eReaderKeyBytes
        self.eReaderKey = try EDeviceKey(from: keyData)
        self.data = data
    }
}

fileprivate extension CBOR {
    static var eReaderKey: CBOR { "eReaderKey" }
    static var data: CBOR { "data" }
}
