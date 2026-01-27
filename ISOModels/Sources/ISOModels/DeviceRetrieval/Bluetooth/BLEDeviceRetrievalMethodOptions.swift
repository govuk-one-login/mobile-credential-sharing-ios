import Foundation
import SwiftCBOR
import Utilities

public enum BLEDeviceRetrievalMethodOptions {
    case peripheralOnly(PeripheralMode)
    case centralOnly(CentralMode)
    case either(PeripheralMode, CentralMode)
}

extension BLEDeviceRetrievalMethodOptions: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        switch self {
        case .centralOnly(let mode):
            return .map([
                .supportsPeripheralServerMode: false,
                .supportsCentralClientMode: true
            ].merging(mode.map(), uniquingKeysWith: { _, _ in true }))
        case .peripheralOnly(let mode):
            return .map([
                .supportsPeripheralServerMode: true,
                .supportsCentralClientMode: false
            ].merging(mode.map(), uniquingKeysWith: { _, _ in true }))
        case .either(let peripheral, let central):
            return .map(
                [
                    .supportsPeripheralServerMode: true,
                    .supportsCentralClientMode: true
                ]
                .merging(peripheral.map(), uniquingKeysWith: { _, _ in true })
                .merging(central.map(), uniquingKeysWith: { _, _ in true })
            )
        }
    }
    
    public static func decode(from cborMap: [CBOR: CBOR]) throws -> Self {
        guard case .boolean(let supportsPeripheralServerMode) = cborMap[.supportsPeripheralServerMode] else {
            throw BLEDeviceRetrievalError.noPeripheralServerMode
        }
        
        guard case .boolean(let supportsCentralClientMode) = cborMap[.supportsCentralClientMode] else {
            throw BLEDeviceRetrievalError.noCentralClientMode
        }
                
        // We only support peripheral mode at the moment - need to add more if central is added
//        if supportsPeripheralServerMode && !supportsCentralClientMode {
//
//        }
        let peripheralMode = try PeripheralMode.decode(from: cborMap)
        return BLEDeviceRetrievalMethodOptions.peripheralOnly(peripheralMode)
    }
}

fileprivate extension CBOR {
    static var supportsPeripheralServerMode: CBOR { 0 }
    static var supportsCentralClientMode: CBOR { 1 }
}

enum BLEDeviceRetrievalError: Error {
    case noPeripheralServerMode
    case noCentralClientMode
    
    public var errorMessage: String? {
        switch self {
        case .noCentralClientMode:
            "Information on central client mode is missing"
        case .noPeripheralServerMode:
            "Information on peripheral server mode is missing"
        }
    }
}
