import CryptoKit
import Foundation
import Security
import X509

public struct JWTSignatureVerifier: SignatureVerifying {
    public init() {
        // able to initialise outside the package
    }

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

        try validateType(header)
        try validateAlgorithm(header)
        let leafCertDER = try leafCertificateDER(from: header)
        let publicKey = try extractPublicKey(fromDER: leafCertDER)

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

        return VerifiedJWT(
            headerData: headerData,
            payloadData: payloadData,
            leafCertificateSANs: dnsNames(fromDER: leafCertDER)
        )
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

    private func validateType(_ header: [String: Any]) throws(JWTVerificationError) {
        guard let typ = header["typ"] as? String else {
            throw .unsupportedType("none")
        }
        guard typ == "JWT" else {
            throw .unsupportedType(typ)
        }
    }

    private func validateAlgorithm(_ header: [String: Any]) throws(JWTVerificationError) {
        guard let alg = header["alg"] as? String else {
            throw .unsupportedAlgorithm("none")
        }
        guard alg == "ES256" else {
            throw .unsupportedAlgorithm(alg)
        }
    }

    private func leafCertificateDER(from header: [String: Any]) throws(JWTVerificationError) -> Data {
        guard let x5c = header["x5c"] as? [String], let leafCertBase64 = x5c.first else {
            throw .missingX5CHeader
        }

        guard let certData = Data(base64Encoded: leafCertBase64) else {
            throw .invalidCertificateData
        }

        return certData
    }

    private func extractPublicKey(
        fromDER certData: Data
    ) throws(JWTVerificationError) -> P256.Signing.PublicKey {
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

    /// Reads `dNSName` Subject Alternative Names from the DER-encoded leaf certificate.
    /// Returns an empty array when the certificate cannot be parsed as X.509, has no SAN
    /// extension, or has no DNS entries; absence is not a verification failure (the
    /// signature has already been checked against this certificate's key).
    private func dnsNames(fromDER certData: Data) -> [String] {
        guard let certificate = try? Certificate(derEncoded: Array(certData)),
              let san = try? certificate.extensions.subjectAlternativeNames else {
            return []
        }

        return san.compactMap { generalName in
            guard case let .dnsName(name) = generalName else {
                return nil
            }
            return name
        }
    }
}
