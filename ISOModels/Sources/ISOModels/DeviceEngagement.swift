import Foundation
import SwiftCBOR

enum DeviceEngagementError: Error {
    case requestWasIncorrectlyStructured
    case unsupportedRequest
    case noVersion
    case noSecurity
    case noRetrievalMethods
    case incorrectSecurityFormat
    
    public var errorDescription: String? {
        switch self {
        case .requestWasIncorrectlyStructured:
            return "The request was incorrectly structured"
        case .unsupportedRequest:
            return "That request is not supported"
        case .noVersion:
            return "The version number is missing"
        case .noSecurity:
            return "The security array is missing from the map"
        case .noRetrievalMethods:
            return "The retrieval methods are missing from the map"
        case .incorrectSecurityFormat:
            return "The security array is in the incorrect format"
        }
    }
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
    
    public static func decode(from base64QRCode: String) throws -> Self {
        
        guard let qrData: Data = Data(base64URLEncoded: base64QRCode) else {
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        guard let qrCBOR: CBOR = try CBOR.decode([UInt8](qrData)) else {
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        
        // get the version number from the map
        guard case .utf8String(let version) = qrCBOR[.version] else {
            throw DeviceEngagementError.noVersion
        }
        
        // get the security from the map
        guard case .array(let securityArray) = qrCBOR[.security] else {
            throw DeviceEngagementError.noSecurity
        }
        
        let security = try Security.decode(from: securityArray)
        
        // get the retrieval array from the map
        guard case .array(let retrievalArray) = qrCBOR[.deviceRetrievalMethods] else {
            throw DeviceEngagementError.noRetrievalMethods
        }
        
        let deviceRetrievalMethod = try DeviceRetrievalMethod.decode(from: retrievalArray)
        
        return DeviceEngagement(version: version, security: security, deviceRetrievalMethods: [deviceRetrievalMethod])
    }
}

fileprivate extension CBOR {
    static var version: CBOR { 0 }
    static var security: CBOR { 1 }
    static var deviceRetrievalMethods: CBOR { 2 }
}
