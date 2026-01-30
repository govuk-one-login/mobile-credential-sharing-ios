import Foundation
import SwiftCBOR

public struct PeripheralMode {
    public let uuid: UUID
    public let address: String?
    
    public init(uuid: UUID, address: String? = nil) {
        self.uuid = uuid
        self.address = address
    }
    
    init(from cborMap: [CBOR: CBOR]) throws {
        // obtain the uuid bytestring from the cbor map
        guard case .byteString(let uuidBytes) = cborMap[.uuid] else {
            print(PeripheralModeError.noUUID.errorMessage ?? "")
            throw PeripheralModeError.noUUID
        }
        
        // convert the uuid bytes to a UUID object
        let uuid = NSUUID(uuidBytes: uuidBytes) as UUID
        
        self.address = nil
        self.uuid = uuid
    }
    
    public func map() -> [CBOR: CBOR] {
        guard let address else {
            return [
                .uuid: .byteString([UInt8](uuid.data))
            ]
        }
        return [
            .uuid: .byteString([UInt8](uuid.data)),
            .address: .byteString(address.encode())
        ]
    }
}

fileprivate extension CBOR {
    static var uuid: CBOR { 10 }
    static var address: CBOR { 20 }
}

enum PeripheralModeError: Error {
    case noUUID
    case incorrectFormat
    
    public var errorMessage: String? {
        switch self {
        case .noUUID:
            return "The UUID is missing"
        case .incorrectFormat:
            return "The CBOR map was formatted incorrectly"
        }
    }
}
