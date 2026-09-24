import CryptoKit
import Foundation
import SwiftASN1
import X509

/// Concrete ``CoseVerifier`` for the `CoseVerification` module.

public struct CoseVerification: CoseVerifier {

    public init() {
        // No stored properties to set up: this verifier is stateless and composes the
        // module's static stages directly. The initialiser is declared explicitly and
        // public so other modules can construct the type — a struct's implicit initialiser
        // is internal and would not be visible outside this module.
    }

    // MARK: - Chain-based attached (IssuerAuth)

    /// Verifies a certificate-backed attached COSE_Sign1 (IssuerAuth) against a caller-provided
    /// trusted root.
    ///
    /// Composes the module's stages in the order mandated by the IssuerAuth verification sequence:
    ///
    /// 1. **C2** decodes the value and selects its embedded (attached) payload.
    /// 2. **C4** enforces the shared certificate-header profile and extracts the leaf-first
    ///    `x5chain`. `x5bag` is ignored; the protected `x5t` binds the candidate leaf.
    /// 3. **C5** validates the candidate chain against the trusted root (linkage, per-link
    ///    signatures, key-identifier matching, time validity).
    /// 4. **C6** applies the IssuerAuth certificate profile to the trusted path and returns the
    ///    approved end-entity public key.
    /// 5. **C3** verifies the ES256 signature over the attached payload with the verified leaf key.
    ///
    /// On success it returns the verified leaf certificate and the exact attached payload bytes.
    /// If any stage fails, its ``CoseVerificationFailure`` propagates and no result is returned.
    ///
    /// This operation does not decode the payload as an MSO, validate document semantics, acquire
    /// the trust root, or enforce revocation.
    public func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: Certificate
    ) async throws -> CoseVerificationResult {
        // C2: decode the COSE_Sign1 structure (rejects non-ES256, malformed CBOR).
        let decoded = try CoseSign1Decoder.decode(coseSign1Bytes)

        // Select the embedded payload; an attached IssuerAuth must carry a non-nil payload.
        let payload = try PayloadModeValidator.payload(for: .attached, from: decoded)

        // C4: enforce the certificate-header profile and extract the leaf-first x5chain.
        let headerMaterial = try CertificateHeaderValidator.validate(decoded)

        // C5: validate the candidate chain against the caller-provided trusted root.
        // The root is re-serialised to DER for the DER-oriented path validator; the candidate
        // chain is itself DER byte strings taken from the COSE x5chain header.
        let validatedPath = try await CertificatePathValidator.validate(
            certificateChain: headerMaterial.certificateChain,
            trustedRootDer: try derBytes(of: trustedRoot)
        )

        // C6: apply the IssuerAuth certificate profile and obtain the approved leaf public key.
        let leafPublicKey = try await CertificateProfileValidator.validate(
            validatedPath: validatedPath,
            role: .issuerAuth
        )

        // Bridge the swift-certificates leaf key to a CryptoKit P-256 key for signature
        // verification. C5's public-key allow-list admits both P-256 and P-384, so a P-384 leaf is
        // valid caller input that reaches here and is correctly rejected as `unsupportedAlgorithm`:
        // the ISO 18013-5 IssuerAuth signature is ES256, which a P-384 key cannot produce.
        guard let p256LeafKey = P256.Signing.PublicKey(leafPublicKey) else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        // C3: verify the ES256 signature over the attached payload with the verified leaf key.
        let sigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: decoded.protectedHeaderBytes,
            payload: payload
        )
        try ES256SignatureVerifier.verify(
            sigStructure: sigStructure,
            signature: decoded.signature,
            publicKey: p256LeafKey
        )

        // The verified leaf is the first certificate of C5's validated path.
        guard let verifiedLeaf = validatedPath.path.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        return CoseVerificationResult(
            leafCertificate: verifiedLeaf,
            payload: payload
        )
    }

    // MARK: - Chain-based detached (ReaderAuth)

    public func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: Certificate
    ) async throws -> CoseVerificationResult {
        // Not implemented yet (C8). Throws a typed error to satisfy conformance without crashing.
        throw CoseVerificationFailure.unsupportedAlgorithm
    }

    // MARK: - Direct-key detached (DeviceSignature)

    /// Verifies a detached DeviceSignature against a caller-supplied P-256 key.
    /// Decodes (C2), selects the detached payload, then verifies ES256 (C3).
    /// Certificate-header parameters are ignored; success returns no material.
    public func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        publicKey: P256.Signing.PublicKey
    ) throws {
        let decoded = try CoseSign1Decoder.decode(coseSign1Bytes)

        let payload = try PayloadModeValidator.payload(
            for: .detached(externalPayload: detachedPayload),
            from: decoded
        )

        let sigStructure = SigStructureBuilder.build(
            protectedHeaderBytes: decoded.protectedHeaderBytes,
            payload: payload
        )

        try ES256SignatureVerifier.verify(
            sigStructure: sigStructure,
            signature: decoded.signature,
            publicKey: publicKey
        )
    }

    // MARK: - Private helpers

    /// Serialises a parsed ``Certificate`` back to its DER encoding for the DER-oriented path
    /// validator (C5). The trusted root is caller-owned and is not mutated.
    private func derBytes(of certificate: Certificate) throws -> Data {
        var serializer = DER.Serializer()
        do {
            try serializer.serialize(certificate)
        } catch {
            // A trusted root that cannot be re-serialised cannot anchor a chain.
            throw CoseVerificationFailure.untrustedCertificate
        }
        return Data(serializer.serializedBytes)
    }
}
