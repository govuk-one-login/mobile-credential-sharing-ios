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
    
    /// Decodes a `SessionEstablishment` from raw CBOR data.
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
        self.eReaderKey = try EReaderKey(from: keyData)
        self.data = data
    }
    
    /// Constructs a `SessionEstablishment` for encoding and transmission.
    /// - Parameters:
    ///   - eReaderKeyBytes: The COSE_Key bytes (inner content of Tag 24) for the Verifier's ephemeral public key.
    ///   - data: The encrypted `DeviceRequest` byte string (ciphertext + authentication tag).
    public init(eReaderKeyBytes: [UInt8], data: [UInt8]) throws {
        guard let keyData = try CBOR.decode(eReaderKeyBytes) else {
            throw SessionEstablishmentError.cborEReaderKeyFieldMissing
        }
        self.eReaderKeyBytes = eReaderKeyBytes
        self.eReaderKey = try EReaderKey(from: keyData)
        self.data = data
    }
}

extension SessionEstablishment: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        let map: [CBOR: CBOR] = [
            .eReaderKey: .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)),
            .data: .byteString(data)
        ]
        return .map(map)
    }
}

fileprivate extension CBOR {
    static var eReaderKey: CBOR { "eReaderKey" }
    static var data: CBOR { "data" }
}
