import CryptoKit
import Foundation
import Security

struct JWTTestHelper {
    let signingKey: P256.Signing.PrivateKey
    let certificateDER: Data

    init() {
        let key = P256.Signing.PrivateKey()
        self.signingKey = key
        self.certificateDER = Self.createSelfSignedCertificate(for: key)
    }

    func sign(payload: Data, algorithm: String = "ES256", includeX5C: Bool = true) throws -> String {
        var headerDict: [String: Any] = ["alg": algorithm, "typ": "JWT"]
        if includeX5C {
            headerDict["x5c"] = [certificateDER.base64EncodedString()]
        }

        let headerData = try JSONSerialization.data(withJSONObject: headerDict)
        let headerSegment = headerData.base64URLEncodedString()
        let payloadSegment = payload.base64URLEncodedString()

        let signingInput = Data("\(headerSegment).\(payloadSegment)".utf8)
        let signature = try signingKey.signature(for: signingInput)
        let signatureSegment = signature.rawRepresentation.base64URLEncodedString()

        return "\(headerSegment).\(payloadSegment).\(signatureSegment)"
    }

    func signWithCustomHeader(_ headerJSON: Data, payload: Data) throws -> String {
        let headerSegment = headerJSON.base64URLEncodedString()
        let payloadSegment = payload.base64URLEncodedString()

        let signingInput = Data("\(headerSegment).\(payloadSegment)".utf8)
        let signature = try signingKey.signature(for: signingInput)
        let signatureSegment = signature.rawRepresentation.base64URLEncodedString()

        return "\(headerSegment).\(payloadSegment).\(signatureSegment)"
    }
}

extension JWTTestHelper {
    private static func createSelfSignedCertificate(for privateKey: P256.Signing.PrivateKey) -> Data {
        var error: Unmanaged<CFError>?
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256
        ]

        guard let secKey = SecKeyCreateWithData(
            privateKey.x963Representation as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            fatalError("Failed to create SecKey from private key: \(String(describing: error?.takeRetainedValue()))")
        }

        guard let publicSecKey = SecKeyCopyPublicKey(secKey) else {
            fatalError("Failed to extract public key from SecKey")
        }

        // Build a minimal self-signed X.509 v3 certificate in DER format
        return buildDERCertificate(
            publicKey: publicSecKey,
            signingKey: secKey
        )
    }

    private static func buildDERCertificate(publicKey: SecKey, signingKey: SecKey) -> Data {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            fatalError("Failed to get external representation of public key")
        }

        let tbs = buildTBSCertificate(publicKeyData: publicKeyData)
        let signature = signData(tbs, with: signingKey)

        // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
        var cert = Data()
        cert.append(contentsOf: tbs)
        cert.append(contentsOf: ecdsaWithSHA256AlgorithmIdentifier())
        cert.append(contentsOf: derBitString(signature))

        return derSequence(cert)
    }

    private static func buildTBSCertificate(publicKeyData: Data) -> Data {
        var tbs = Data()

        // Version: v3 (explicit tag [0])
        tbs.append(contentsOf: derExplicitTag(0, content: derInteger(Data([0x02]))))

        // Serial number
        tbs.append(contentsOf: derInteger(Data([0x01])))

        // Signature algorithm
        tbs.append(contentsOf: ecdsaWithSHA256AlgorithmIdentifier())

        // Issuer (minimal: CN=Test)
        tbs.append(contentsOf: buildName("Test"))

        // Validity
        tbs.append(contentsOf: buildValidity())

        // Subject (same as issuer for self-signed)
        tbs.append(contentsOf: buildName("Test"))

        // Subject Public Key Info
        tbs.append(contentsOf: buildSubjectPublicKeyInfo(publicKeyData))

        return derSequence(tbs)
    }

    private static func ecdsaWithSHA256AlgorithmIdentifier() -> Data {
        // OID 1.2.840.10045.4.3.2 (ecdsa-with-SHA256)
        let oid: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]
        return derSequence(Data(oid))
    }

    private static func buildName(_ commonName: String) -> Data {
        // RDNSequence with a single RDN containing CN
        let cnOID: [UInt8] = [0x06, 0x03, 0x55, 0x04, 0x03] // OID 2.5.4.3
        let cnValue = derUTF8String(commonName)
        let attrTypeAndValue = derSequence(Data(cnOID) + cnValue)
        let rdn = derSet(attrTypeAndValue)
        return derSequence(rdn)
    }

    private static func buildValidity() -> Data {
        // Not Before: 2024-01-01, Not After: 2034-01-01
        let notBefore = derUTCTime("240101000000Z")
        let notAfter = derUTCTime("340101000000Z")
        return derSequence(notBefore + notAfter)
    }

    private static func buildSubjectPublicKeyInfo(_ publicKeyData: Data) -> Data {
        // Algorithm: EC with P-256
        let ecOID: [UInt8] = [0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01] // 1.2.840.10045.2.1
        let p256OID: [UInt8] = [0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07] // 1.2.840.10045.3.1.7
        let algorithmIdentifier = derSequence(Data(ecOID) + Data(p256OID))
        let publicKeyBits = derBitString(publicKeyData)
        return derSequence(algorithmIdentifier + publicKeyBits)
    }

    private static func signData(_ data: Data, with key: SecKey) -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            key,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            fatalError("Failed to create signature: \(String(describing: error?.takeRetainedValue()))")
        }
        return signature
    }

    // MARK: - DER Encoding Helpers

    private static func derSequence(_ content: Data) -> Data {
        derTLV(tag: 0x30, content: content)
    }

    private static func derSet(_ content: Data) -> Data {
        derTLV(tag: 0x31, content: content)
    }

    private static func derInteger(_ value: Data) -> Data {
        derTLV(tag: 0x02, content: value)
    }

    private static func derBitString(_ content: Data) -> Data {
        // Prepend 0x00 (no unused bits)
        derTLV(tag: 0x03, content: Data([0x00]) + content)
    }

    private static func derUTF8String(_ string: String) -> Data {
        derTLV(tag: 0x0C, content: Data(string.utf8))
    }

    private static func derUTCTime(_ time: String) -> Data {
        derTLV(tag: 0x17, content: Data(time.utf8))
    }

    private static func derExplicitTag(_ tag: UInt8, content: Data) -> Data {
        derTLV(tag: 0xA0 | tag, content: content)
    }

    private static func derTLV(tag: UInt8, content: Data) -> Data {
        var result = Data([tag])
        let length = content.count
        if length < 0x80 {
            result.append(UInt8(length))
        } else if length <= 0xFF {
            result.append(contentsOf: [0x81, UInt8(length)])
        } else {
            result.append(contentsOf: [0x82, UInt8(length >> 8), UInt8(length & 0xFF)])
        }
        result.append(content)
        return result
    }
}
