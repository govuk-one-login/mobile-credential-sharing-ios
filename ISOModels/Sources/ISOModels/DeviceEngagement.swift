import Foundation
import SwiftCBOR

enum DeviceEngagementError: Error {
    case requestWasIncorrectlyStructured
    case unsupportedRequest
}

public struct DeviceEngagement {
    let version: String
    let security: Security
    let deviceRetrievalMethods: [DeviceRetrievalMethod]?
    
    public init(
        version: String = "1.0",
        security: Security,
        deviceRetrievalMethods: [DeviceRetrievalMethod]?
    ) {
        self.version = version
        self.security = security
        self.deviceRetrievalMethods = deviceRetrievalMethods
    }
}

extension DeviceEngagement: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        guard deviceRetrievalMethods != nil && !deviceRetrievalMethods!.isEmpty else {
        return .map([
            .version: .utf8String(version),
            .security: security.toCBOR(options: options)
        ])
    }

    return .map([
        .version: .utf8String(version),
        .security: security.toCBOR(options: options),
        .deviceRetrievalMethods: deviceRetrievalMethods!.toCBOR()
    ])
}
}

fileprivate extension CBOR {
    static var version: CBOR { 0 }
    static var security: CBOR { 1 }
    static var deviceRetrievalMethods: CBOR { 2 }
}
