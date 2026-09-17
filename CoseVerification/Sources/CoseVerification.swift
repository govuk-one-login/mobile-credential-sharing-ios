import Foundation
import Security

/// Concrete ``CoseVerifier`` for the `CoseVerification` module.

public struct CoseVerification: CoseVerifier {

    public init() {}

    public func verifyAttached(
        coseSign1Bytes: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
        fatalError("verifyAttached is not implemented yet")
    }

    public func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        trustedRoot: SecCertificate
    ) throws -> CoseVerificationResult {
        fatalError("verifyDetached(trustedRoot:) is not implemented yet")
    }

    // MARK: - Direct-key detached (DeviceSignature) — C9

    /// Verifies a detached DeviceSignature against a caller-supplied P-256 key.
    /// Decodes (C2), selects the detached payload, then verifies ES256 (C3).
    /// Certificate-header parameters are ignored; success returns no material.
    public func verifyDetached(
        coseSign1Bytes: Data,
        detachedPayload: Data,
        publicKey: SecKey
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
