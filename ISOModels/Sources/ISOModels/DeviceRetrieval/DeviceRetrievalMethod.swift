import Foundation
import SwiftCBOR
import Utilities

public enum DeviceRetrievalMethod {
    case bluetooth(BLEDeviceRetrievalMethodOptions)
    
    var type: UInt64 { 2 }
    var version: UInt64 { 1 }
}

extension DeviceRetrievalMethod: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        switch self {
        case .bluetooth(let retrievalOptions):
            return .array([
                .bluetooth,
                .unsignedInt(version),
                retrievalOptions.toCBOR(options: options)
            ])
        }
    }
    
    public static func decode(from nestedCBORArray: [CBOR]) throws -> Self {
        let deviceRetrievalArray = nestedCBORArray[0]
        
        // get transport type - will be needed when bluetooth isn't only option
        guard case .unsignedInt(let type) = deviceRetrievalArray[0] else {
            throw DeviceRetrievalError.noTransport
        }
        
        
        // get version - will be needed when the enum isn't hard coded
        guard case .unsignedInt(let version) = deviceRetrievalArray[1] else {
            throw DeviceRetrievalError.noVersion
        }
        
        
        // get retrieval methods
        guard case .map(let retrievalMethods) = deviceRetrievalArray[2] else {
            throw DeviceRetrievalError.noRetrievalMethods
        }
        let retrievalMethodsOptions = try BLEDeviceRetrievalMethodOptions.decode(from: retrievalMethods)
        
        return DeviceRetrievalMethod.bluetooth(retrievalMethodsOptions)
    }
}

fileprivate extension CBOR {
    static var bluetooth: CBOR { 2 }
}

enum DeviceRetrievalError: Error {
    case incorrectFormat
    case noTransport
    case noVersion
    case noRetrievalMethods
    
    var errorMessage: String? {
        switch self {
        case .incorrectFormat:
            return "CBOR array was formatted incorrectly"
        case .noTransport:
            return "Transport type is missing"
        case .noVersion:
            return "Version number is missing"
        case .noRetrievalMethods:
            return "Retrieval methods are missing"
        }
    }
}
