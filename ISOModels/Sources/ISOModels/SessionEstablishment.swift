import Foundation
import SwiftCBOR

enum SessionEstablishmentError: Error {
    case requestWasIncorrectlyStructured
}

public struct SessionEstablishment {
    public let keyBytes: [UInt8]
    public let data: [UInt8]
    
    public init(data: Data) throws {
        let decodedCBOR = try CBOR.decode([UInt8](data))

        guard case let .map(request) = decodedCBOR,
              case let .tagged(.encodedCBORDataItem, .byteString(eReaderKeyBytes)) = request[.eReaderKey],
              case let .byteString(data) = request[.data]
        else {
            throw SessionEstablishmentError.requestWasIncorrectlyStructured
        }

        self.keyBytes = eReaderKeyBytes
        self.data = data
    }
}

fileprivate extension CBOR {
    static var eReaderKey: CBOR { "eReaderKey" }
    static var data: CBOR { "data" }
}
