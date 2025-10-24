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
}

fileprivate extension CBOR {
    static var supportsPeripheralServerMode: CBOR { 0 }
    static var supportsCentralClientMode: CBOR { 1 }
}
