import Foundation

struct PeripheralMode {
    public let uuid: UUID
    public let address: String?
    
    public init(uuid: UUID, address: String?) {
        self.uuid = uuid
        self.address = address
    }
}
