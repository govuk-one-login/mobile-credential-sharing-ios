import Foundation
import SwiftCBOR

enum DeviceEngagementError: Error {
    case requestWasIncorrectlyStructured
    case unsupportedRequest
    case missingVersion
    case missingSecurity
    case missingRetrievalMethods
    
    public var errorDescription: String? {
        switch self {
        case .requestWasIncorrectlyStructured:
            return "The request was incorrectly structured"
        case .unsupportedRequest:
            return "That request is not supported"
        case .missingVersion:
            return "The version number is missing"
        case .missingSecurity:
            return "The security is missing from the map"
        case .missingRetrievalMethods:
            return "The retrieval methods are missing from the map"
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
    
    public static func decode() throws -> [CBOR: CBOR] {
        let exampleString: String = "owBjMS4wAYIB2BhYS6QBAiABIVggVfvhhCVTTs1tL-6aQemxecCx_E1iL-F8vnKhlli9aAUiWCB_Dv4CTLvQ3ywTKQuEoDSZ9wnDq5aFJGLfJFNAsOqy5QKBgwIBowD1AfQKUGyqBZ4EGkU_kCmGmL9VmAk"
        
        guard let exampleData: Data = Data(base64URLEncoded: exampleString) else {
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        guard let exampleCBOR: CBOR = try CBOR.decode([UInt8](exampleData)) else {
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        guard case .map(let exampleCBORMap) = exampleCBOR else {
            throw DeviceEngagementError.requestWasIncorrectlyStructured
        }
        
        guard case .utf8String(let version) = exampleCBOR[.version] else {
            throw DeviceEngagementError.missingVersion
        }
        
        guard case .array(let securityArray) = exampleCBOR[.security] else {
            throw DeviceEngagementError.missingSecurity
        }

        guard case .unsignedInt(let security) = securityArray[0] else {
            throw DeviceEngagementError.missingSecurity
        }
        
        guard case .array(let retrievalArray) = exampleCBOR[.deviceRetrievalMethods] else {
            throw DeviceEngagementError.missingRetrievalMethods
        }

        print("Retrieval Array: \(retrievalArray)")
        print("Security: \(security)")
        print("Version: \(version)")
        return exampleCBORMap
        
        
    }
}

fileprivate extension CBOR {
    static var version: CBOR { 0 }
    static var security: CBOR { 1 }
    static var deviceRetrievalMethods: CBOR { 2 }
}
