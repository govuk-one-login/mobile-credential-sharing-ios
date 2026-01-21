import Foundation

public enum COSEKeyError: LocalizedError, Equatable {
    case unsupportedCurve(Curve)
}
