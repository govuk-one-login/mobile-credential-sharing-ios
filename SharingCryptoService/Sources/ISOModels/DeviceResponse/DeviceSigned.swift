import Foundation
import SwiftCBOR

public struct DeviceSigned: Equatable, Hashable {
    let nameSpaces: [UInt8]
    let deviceAuth: DeviceAuth
    
    public init(nameSpaces: [UInt8], deviceAuth: DeviceAuth) {
        self.nameSpaces = nameSpaces
        self.deviceAuth = deviceAuth
    }
}

extension DeviceSigned: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .nameSpaces: .byteString(nameSpaces),
            .deviceAuth: deviceAuth.toCBOR(options: options)
        ])
    }
}

fileprivate extension CBOR {
    static var nameSpaces: CBOR { "nameSpaces" }
    static var deviceAuth: CBOR { "deviceAuth" }
}
