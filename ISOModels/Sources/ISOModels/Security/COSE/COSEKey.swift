import Foundation
import SwiftCBOR

public struct COSEKey {
    let curve: Curve
    let xCoordinate: [UInt8]
    let yCoordinate: [UInt8]

    public init(
        curve: Curve,
        xCoordinate: [UInt8],
        yCoordinate: [UInt8]
    ) {
        self.curve = curve
        self.xCoordinate = xCoordinate
        self.yCoordinate = yCoordinate
    }
    
    public init(from cbor: CBOR) throws {
        guard case .map(let key) = cbor,
              case .unsignedInt(let curveValue) = key[.curve],
              let curve = Curve(rawValue: curveValue),
              case .byteString(let xCoordinate) = key[.xCoordinate],
              case .byteString(let yCoordinate) = key[.yCoordinate] else {
            throw CBORError.wrongTypeInsideSequence
        }
        self.curve = curve
        self.xCoordinate = xCoordinate
        self.yCoordinate = yCoordinate
    }
}

extension COSEKey: CBOREncodable {
    public func toCBOR(options: CBOROptions) -> CBOR {
        [
            .keyType: curve.keyType.toCBOR(options: options),
            .curve: curve.toCBOR(options: options),
            .xCoordinate: .byteString(xCoordinate),
            .yCoordinate: .byteString(yCoordinate)
        ]
    }
    
    public static func decode(from eDeviceKeyBytes: [UInt8]) throws -> Self {
        guard let eDeviceKeyCBOR = try CBOR.decode(eDeviceKeyBytes) else {
            throw KeyError.cannotDecode
        }
        
        // get key type from map - will be needed when more than 1 key type is available
        guard case .unsignedInt(let keyType) = eDeviceKeyCBOR[.keyType] else {
            throw KeyError.noKeyType
        }
        
        // get curve from map - potential issue here, had to use negative int 0 instead of .curve defined in the iso spec to decode
        guard case .unsignedInt(let curve) = eDeviceKeyCBOR[CBOR.negativeInt(0)] else {
            throw KeyError.noCurve
        }
        // check curve is defined
        guard let curve = Curve(rawValue: curve) else {
            throw KeyError.noCurve
        }
        
        // get x coord from map - same here as issue above
        guard case .byteString(let xCoordinate) = eDeviceKeyCBOR[CBOR.negativeInt(1)] else {
            throw KeyError.noxCoordinate
        }
        
        // get y coord from map - and again
        guard case .byteString(let yCoordinate) = eDeviceKeyCBOR[CBOR.negativeInt(2)] else {
            throw KeyError.noyCoordinate
        }
        
        return COSEKey(curve: curve, xCoordinate: xCoordinate, yCoordinate: yCoordinate)
    }
}

fileprivate extension CBOR {
    static var keyType: CBOR { 1 }
    static var curve: CBOR { -1 }
    static var xCoordinate: CBOR { -2 }
    static var yCoordinate: CBOR { -3 }
}

enum KeyError: Error {
    case cannotDecode
    case noKeyType
    case noCurve
    case noxCoordinate
    case noyCoordinate
    
    public var errorDescription: String? {
        switch self {
        case .cannotDecode:
            return "Cannot decode eDevice key byte array into cbor"
        case .noKeyType:
            return "Cannot find key type"
        case .noCurve:
            return "Cannot find curve"
        case .noxCoordinate:
            return "Cannot find x coordinate"
        case .noyCoordinate:
            return "Cannot find y coordinate"
        }
    }
}
