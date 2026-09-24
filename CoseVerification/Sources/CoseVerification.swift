import CryptoKit
import Foundation
import Security

/// Concrete ``CoseVerifier`` for the `CoseVerification` module.

public struct CoseVerification: CoseVerifier {

    public init() {
        // No stored properties to set up: this verifier is stateless and composes the
        // module's static stages directly. The initialiser is declared explicitly and
        // public so other modules can construct the type — a struct's implicit initialiser
        // is internal and would not be visible outside this module.
    }

    public func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
        // Not implemented yet (C7). Throws a typed error to satisfy conformance without crashing.
        throw CoseVerificationFailure.unsupportedAlgorithm
    }

    public func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
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
}
