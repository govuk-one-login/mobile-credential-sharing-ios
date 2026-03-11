import CryptoKit
import Foundation

public enum COSEKeyError: LocalizedError, Equatable {
    case unsupportedCurve(Curve)
    case malformedKeyData(CryptoKitError)
}
