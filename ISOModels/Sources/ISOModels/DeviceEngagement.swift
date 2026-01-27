import Foundation
import SwiftCBOR

enum DeviceEngagementError: Error {
    case requestWasIncorrectlyStructured
    case unsupportedRequest
    case noVersion
    case incorrectVersion
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
        case .incorrectVersion:
            return "That version is not currently supported"
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
            print(DeviceEngagementError.requestWasIncorrectlyStructured.errorDescription ?? "")
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        guard let qrCBOR: CBOR = try CBOR.decode([UInt8](qrData)) else {
            print(DeviceEngagementError.requestWasIncorrectlyStructured.errorDescription ?? "")
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        
        // get the version number from the map
        guard case .utf8String(let version) = qrCBOR[.version] else {
            print(DeviceEngagementError.noVersion.errorDescription ?? "")
            throw DeviceEngagementError.noVersion
        }
        
        // check that the version is correct
        guard version == "1.0" else {
            print(DeviceEngagementError.incorrectVersion.errorDescription ?? "")
            throw DeviceEngagementError.incorrectVersion
        }
        
        // get the security from the map
        guard case .array(let securityArray) = qrCBOR[.security] else {
            print(DeviceEngagementError.noSecurity.errorDescription ?? "")
            throw DeviceEngagementError.noSecurity
        }
        
        let security = try Security.decode(from: securityArray)
        
        // get the retrieval array from the map
        guard case .array(let retrievalArray) = qrCBOR[.deviceRetrievalMethods] else {
            print(DeviceEngagementError.noRetrievalMethods.errorDescription ?? "")
            throw DeviceEngagementError.noRetrievalMethods
        }
        
        let deviceRetrievalMethod = try DeviceRetrievalMethod.decode(from: retrievalArray)
        let deviceEngagement = DeviceEngagement(version: version, security: security, deviceRetrievalMethods: [deviceRetrievalMethod])
        print(deviceEngagement)
        return deviceEngagement
    }
}

fileprivate extension CBOR {
    static var version: CBOR { 0 }
    static var security: CBOR { 1 }
    static var deviceRetrievalMethods: CBOR { 2 }
}
