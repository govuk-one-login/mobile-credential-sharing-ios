import Foundation

public enum JWTVerificationError: Error, Sendable, Equatable {
    case invalidStructure
    case headerDecodingFailed
    case unsupportedAlgorithm(String)
    case missingX5CHeader
    case invalidCertificateData
    case invalidSignature
    case payloadDecodingFailed
}
