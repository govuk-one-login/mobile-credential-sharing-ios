import Foundation
import SharingLogging
import SwiftCBOR

public enum BLEDeviceRetrievalMethodOptions {
    case peripheralOnly(PeripheralMode)
    case centralOnly(CentralMode)
    case either(PeripheralMode, CentralMode)

    public var peripheralServiceUUID: UUID? {
        switch self {
        case .peripheralOnly(let mode), .either(let mode, _):
            return mode.uuid
        case .centralOnly:
            return nil
        }
    }
}

extension BLEDeviceRetrievalMethodOptions: CBOREncodable {
    init(from cborMap: [CBOR: CBOR]) throws {
        // extract peripheral mode bool from cbor map
        guard case .boolean(let supportsPeripheralServerMode) = cborMap[.supportsPeripheralServerMode] else {
            Logger.log(BLEDeviceRetrievalError.noPeripheralServerMode.errorMessage ?? "", level: .error)
            throw BLEDeviceRetrievalError.noPeripheralServerMode
        }
        
        // extract central mode bool from map
        guard case .boolean(let supportsCentralClientMode) = cborMap[.supportsCentralClientMode] else {
            Logger.log(BLEDeviceRetrievalError.noCentralClientMode.errorMessage ?? "", level: .error)
            throw BLEDeviceRetrievalError.noCentralClientMode
        }
        
        switch (supportsPeripheralServerMode, supportsCentralClientMode) {
        case (true, true):
            // .either(PeripheralMode, CentralMode)
            let peripheralMode = try PeripheralMode(from: cborMap)
            let centralMode = try CentralMode(from: cborMap)
            self = .either(peripheralMode, centralMode)
        case (true, false):
            // .peripheralOnly(PeripheralMode)
            let peripheralMode = try PeripheralMode(from: cborMap)
            self = .peripheralOnly(peripheralMode)
        case (false, true):
            // .centralOnly(CentralMode)
            let centralMode = try CentralMode(from: cborMap)
            self = .centralOnly(centralMode)
        case (false, false):
            // this means niether option is available -- will always fail
            Logger.log(BLEDeviceRetrievalError.noRetreivalMethodsAvailable.errorMessage ?? "", level: .error)
            throw BLEDeviceRetrievalError.noRetreivalMethodsAvailable
        }
    }
    
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

enum BLEDeviceRetrievalError: Error {
    case noPeripheralServerMode
    case noCentralClientMode
    case noRetreivalMethodsAvailable
    
    public var errorMessage: String? {
        switch self {
        case .noCentralClientMode:
            "Information on central client mode is missing"
        case .noPeripheralServerMode:
            "Information on peripheral server mode is missing"
        case .noRetreivalMethodsAvailable:
            "Neither retreival method was available"
        }
    }
}
