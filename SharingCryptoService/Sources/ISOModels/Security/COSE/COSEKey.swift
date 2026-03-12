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
}

fileprivate extension CBOR {
    static var keyType: CBOR { 1 }
    static var curve: CBOR { -1 }
    static var xCoordinate: CBOR { -2 }
    static var yCoordinate: CBOR { -3 }
}
