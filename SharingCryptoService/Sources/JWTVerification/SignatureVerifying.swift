import Foundation

public protocol SignatureVerifying: Sendable {
    func verify(jwt: String) throws(JWTVerificationError) -> VerifiedJWT
}
