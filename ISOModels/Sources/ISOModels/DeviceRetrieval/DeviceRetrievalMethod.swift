import Foundation
import SwiftCBOR
import Utilities

enum DeviceRetrievalMethod {
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
}

fileprivate extension CBOR {
    static var bluetooth: CBOR { 2 }
}
