import Foundation
import SwiftCBOR

public struct DeviceAuth: Equatable, Hashable, Sendable {
    let deviceSignature: CBOR
    
    public init(deviceSignature: CBOR) {
        self.deviceSignature = deviceSignature
    }
}

extension DeviceAuth: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        .map([
            .deviceSignature: deviceSignature
        ])
    }
}

fileprivate extension CBOR {
    static var deviceSignature: CBOR { "deviceSignature" }
}
