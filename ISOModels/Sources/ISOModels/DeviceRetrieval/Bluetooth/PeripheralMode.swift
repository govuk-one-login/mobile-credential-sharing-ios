import Foundation
import SwiftCBOR

public struct PeripheralMode {
    public let uuid: UUID
    public let address: String?
    
    public init(uuid: UUID, address: String? = nil) {
        self.uuid = uuid
        self.address = address
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
