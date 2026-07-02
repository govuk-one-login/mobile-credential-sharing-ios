import CryptoKit
import Foundation
import Security

public struct JWTSignatureVerifier: SignatureVerifying {
    public init() {}

    public func verify(jwt: String) throws(JWTVerificationError) -> VerifiedJWT {
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw .invalidStructure
        }

        let headerSegment = String(parts[0])
        let payloadSegment = String(parts[1])
        let signatureSegment = String(parts[2])

        let headerData = try decodeHeader(headerSegment)
        let header = try parseHeader(headerData)

        try validateAlgorithm(header)
        let publicKey = try extractPublicKey(from: header)

        guard let payloadData = Data(base64URLEncoded: payloadSegment) else {
            throw .payloadDecodingFailed
        }

        guard let signatureData = Data(base64URLEncoded: signatureSegment) else {
            throw .invalidSignature
        }

        let signingInput = Data("\(headerSegment).\(payloadSegment)".utf8)

        guard let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signatureData),
              publicKey.isValidSignature(signature, for: signingInput) else {
            throw .invalidSignature
        }

        return VerifiedJWT(headerData: headerData, payloadData: payloadData)
    }
}

extension JWTSignatureVerifier {
    private func decodeHeader(_ segment: String) throws(JWTVerificationError) -> Data {
        guard let data = Data(base64URLEncoded: segment) else {
            throw .headerDecodingFailed
        }
        return data
    }

    private func parseHeader(_ data: Data) throws(JWTVerificationError) -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw .headerDecodingFailed
        }
        return json
    }

    private func validateAlgorithm(_ header: [String: Any]) throws(JWTVerificationError) {
        guard let alg = header["alg"] as? String else {
            throw .unsupportedAlgorithm("none")
        }
        guard alg == "ES256" else {
            throw .unsupportedAlgorithm(alg)
        }
    }

    private func extractPublicKey(from header: [String: Any]) throws(JWTVerificationError) -> P256.Signing.PublicKey {
        guard let x5c = header["x5c"] as? [String], let leafCertBase64 = x5c.first else {
            throw .missingX5CHeader
        }

        guard let certData = Data(base64Encoded: leafCertBase64) else {
            throw .invalidCertificateData
        }

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw .invalidCertificateData
        }

        guard let secKey = SecCertificateCopyKey(certificate) else {
            throw .invalidCertificateData
        }

        guard let keyData = SecKeyCopyExternalRepresentation(secKey, nil) as Data? else {
            throw .invalidCertificateData
        }

        guard let publicKey = try? P256.Signing.PublicKey(x963Representation: keyData) else {
            throw .invalidCertificateData
        }

        return publicKey
    }
}
