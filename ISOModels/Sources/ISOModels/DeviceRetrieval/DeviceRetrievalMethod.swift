import Foundation
import SwiftCBOR
import Utilities

public enum DeviceRetrievalMethod {
    case bluetooth(BLEDeviceRetrievalMethodOptions)
    
    var type: UInt64 { 2 }
    var version: UInt64 { 1 }
}

extension DeviceRetrievalMethod: CBOREncodable {
    init(from nestedCBORArray: [CBOR]) throws {
        let deviceRetrievalArray = nestedCBORArray[0]
        
        // transport type - will be needed when bluetooth isn't only option
        guard case .unsignedInt(let type) = deviceRetrievalArray[0] else {
            print(DeviceRetrievalError.noTransport.errorMessage ?? "")
            throw DeviceRetrievalError.noTransport
        }
        
        
        // version - will be needed when the enum isn't hard coded
        guard case .unsignedInt(let version) = deviceRetrievalArray[1] else {
            print(DeviceRetrievalError.noVersion.errorMessage ?? "")
            throw DeviceRetrievalError.noVersion
        }
        
        // check bluetooth version is correct
        guard version == 1 else {
            print(DeviceRetrievalError.incorrectBluetoothVersion.errorMessage ?? "")
            throw DeviceRetrievalError.incorrectBluetoothVersion
        }
        
        // retrieval methods
        guard case .map(let retrievalMethods) = deviceRetrievalArray[2] else {
            print(DeviceRetrievalError.noRetrievalMethods.errorMessage ?? "")
            throw DeviceRetrievalError.noRetrievalMethods
        }
        
        let retrievalMethodsOptions = try BLEDeviceRetrievalMethodOptions(from: retrievalMethods)
        
        switch type {
        case 2:
            // this is bluetooth
            self = .bluetooth(retrievalMethodsOptions)
        default:
            // something has gone wrong for this to execute
            print(DeviceRetrievalError.incorrectRetreivalMethod.errorMessage ?? "")
            throw DeviceRetrievalError.incorrectRetreivalMethod
        }
    }
    
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
}

fileprivate extension CBOR {
    static var bluetooth: CBOR { 2 }
}

enum DeviceRetrievalError: Error {
    case incorrectFormat
    case noTransport
    case noVersion
    case noRetrievalMethods
    case incorrectRetreivalMethod
    case incorrectBluetoothVersion
    
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
        case .incorrectRetreivalMethod:
            return "That retreival method is not currently supported"
        case .incorrectBluetoothVersion:
            return "That bluetooth version is not currently supported"
        }
    }
}
