import Foundation
import SwiftCBOR

public struct DeviceAuth: Equatable, Hashable {
    let deviceSignature: [UInt8]
    
    public init(deviceSignature: [UInt8]) {
        self.deviceSignature = deviceSignature
    }
}

extension DeviceAuth: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .deviceSignature: .byteString(deviceSignature)
        ])
    }
}

fileprivate extension CBOR {
    static var deviceSignature: CBOR { "deviceSignature" }
}
