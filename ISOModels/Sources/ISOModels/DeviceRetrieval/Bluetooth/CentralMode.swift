import Foundation
import SwiftCBOR

public struct CentralMode {
    public let uuid: UUID
    
    public init(uuid: UUID) {
        self.uuid = uuid
    }
    
    init(from cborMap: [CBOR: CBOR]) throws {
        // obtain the uuid bytestring from the cbor map
        guard case .byteString(let uuidBytes) = cborMap[.uuid] else {
            print(CentralModeError.noUUID.errorMessage ?? "")
            throw CentralModeError.noUUID
        }
        
        // convert the uuid bytes to a UUID object
        let uuid = NSUUID(uuidBytes: uuidBytes) as UUID
        
        self.uuid = uuid
    }
    
    func map() -> [CBOR: CBOR] {
        [
            .uuid: .byteString([UInt8](uuid.data))
        ]
    }
}

fileprivate extension CBOR {
    static var uuid: CBOR { 11 }
}

enum CentralModeError: Error {
    case noUUID
    
    var errorMessage: String? { "The UUID is missing" }
}
