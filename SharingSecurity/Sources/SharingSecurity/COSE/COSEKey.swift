import Foundation

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
}
