import CryptoKit
import Foundation
import SwiftCBOR
import X509

/// Produces the detached `COSE_Sign1` ReaderAuth (ISO/IEC 18013-5:2021 §9.1.4) over
/// `ReaderAuthenticationBytes`, signing with the session-provided leaf private key.
///
/// Header profile (mirrors the shared CoseVerification certificate-header profile):
/// - Protected `alg` (1): ES256 (`-7`); `x5t` (34): `[-16, SHA-256(leafDER)]`
/// - Unprotected `x5chain` (33): single byte string (one cert) or ordered array (two or more)
/// - External AAD: empty; payload: `null`; signature: 64-byte raw `r || s`
public struct ReaderAuthGenerator {

    /// Generates the detached ReaderAuth `COSE_Sign1` for the given payload and signing material.
    /// - Throws: `ReaderAuthGenerationFailure` for an invalid credential or a signing failure.
    public static func generate(
        payload: Data,
        signingMaterial: ReaderAuthSigningMaterial
    ) throws -> Data {
        let leafDER = try validatedLeafDER(signingMaterial.certificateChain)

        let protectedHeaderBytes = buildProtectedHeader(leafDER: leafDER)
        let unprotectedHeaderBytes = buildUnprotectedHeader(chain: signingMaterial.certificateChain)
        let sigStructure = buildSigStructure(
            protectedHeaderBytes: protectedHeaderBytes,
            payload: payload
        )

        let rawSignature: Data
        do {
            rawSignature = try signingMaterial.leafPrivateKey.signature(for: sigStructure).rawRepresentation
        } catch {
            throw ReaderAuthGenerationFailure.signingFailed
        }

        return assembleCoseSign1(
            protectedHeaderBytes: protectedHeaderBytes,
            unprotectedHeaderBytes: unprotectedHeaderBytes,
            rawSignature: rawSignature
        )
    }

    // MARK: - Credential validation

    /// Returns the leaf DER after confirming the chain is non-empty and every entry parses as an
    /// X.509 certificate.
    private static func validatedLeafDER(_ chain: [Data]) throws -> Data {
        guard let leafDER = chain.first else {
            throw ReaderAuthGenerationFailure.invalidSigningCredential
        }

        do {
            _ = try chain.map { try Certificate(derEncoded: [UInt8]($0)) }
        } catch {
            throw ReaderAuthGenerationFailure.invalidSigningCredential
        }

        return leafDER
    }

    // MARK: - Header construction

    /// Protected header `{1: -7, 34: [-16, SHA-256(leafDER)]}`, canonically encoded.
    static func buildProtectedHeader(leafDER: Data) -> Data {
        let digest = Data(SHA256.hash(data: leafDER))
        let map: CBOR = .map([
            .unsignedInt(1): .negativeInt(6),
            .unsignedInt(34): .array([
                .negativeInt(15),
                .byteString([UInt8](digest))
            ])
        ])
        return Data(map.encode())
    }

    /// Unprotected header `{33: x5chain}`. Per RFC 9360 §2, one certificate encodes as a byte
    /// string; two or more as an ordered leaf-first array of byte strings.
    static func buildUnprotectedHeader(chain: [Data]) -> Data {
        let x5chain: CBOR
        if chain.count == 1 {
            x5chain = .byteString([UInt8](chain[0]))
        } else {
            x5chain = .array(chain.map { .byteString([UInt8]($0)) })
        }
        let map: CBOR = .map([.unsignedInt(33): x5chain])
        return Data(map.encode())
    }

    /// `Sig_structure = ["Signature1", protectedHeaderBytes, h'', payload]`.
    static func buildSigStructure(protectedHeaderBytes: Data, payload: Data) -> Data {
        let sigStructure: CBOR = .array([
            .utf8String("Signature1"),
            .byteString([UInt8](protectedHeaderBytes)),
            .byteString([]),
            .byteString([UInt8](payload))
        ])
        return Data(sigStructure.encode())
    }

    /// Untagged four-element array `[protectedHeaderBytes, unprotectedHeaderMap, null, signature]`.
    static func assembleCoseSign1(
        protectedHeaderBytes: Data,
        unprotectedHeaderBytes: Data,
        rawSignature: Data
    ) -> Data {
        var bytes: [UInt8] = [0x84]
        bytes += CBOR.byteString([UInt8](protectedHeaderBytes)).encode()
        bytes += [UInt8](unprotectedHeaderBytes)
        bytes += CBOR.null.encode()
        bytes += CBOR.byteString([UInt8](rawSignature)).encode()
        return Data(bytes)
    }
}
