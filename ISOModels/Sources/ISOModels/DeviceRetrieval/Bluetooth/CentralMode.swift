import Foundation
import SwiftCBOR

public struct CentralMode {
    public let uuid: UUID
    
    public init(uuid: UUID) {
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
