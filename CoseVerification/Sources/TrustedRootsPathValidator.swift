import Foundation
import X509

/// Validates a candidate chain against several trusted roots (C10).
///
/// Calls ``CertificatePathValidator`` (C5) with each supplied root until one trusts the chain,
/// supporting root rotation. Returns C5's validated path unchanged and does not reveal which root
/// matched. Profile (C6) and signature (C3) checks belong to their own layers.
enum TrustedRootsPathValidator {
    /// Validates the leaf-first chain against the supplied trusted roots.
    ///
    /// - Parameters:
    ///   - certificateChain: Leaf-first candidate DER (excluding the root).
    ///   - trustedRoots: Non-empty trusted roots (DER), already deduplicated by the caller.
    ///   - expiryPolicy: RFC 5280 expiry policy passed to C5; tests inject a fixed-time policy.
    /// - Returns: C5's validated path for the first trusting root.
    /// - Throws: `untrustedCertificate` for an empty list, a chain containing a supplied root, or
    ///   no trusting root. Any other C5 failure (e.g. `unsupportedAlgorithm`) propagates and stops.
    static func validate(
        certificateChain: [Data],
        trustedRoots: [Data],
        expiryPolicy: CertificatePathValidator.ExpiryPolicyProvider = RFC5280Policy.init
    ) async throws -> [Data] {
        // Empty list is invalid input; reject before any C5 call.
        guard !trustedRoots.isEmpty else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        // A chain containing a supplied root cannot be made acceptable by another root.
        let rootSet = Set(trustedRoots)
        guard !certificateChain.contains(where: rootSet.contains) else {
            throw CoseVerificationFailure.untrustedCertificate
        }

        for root in trustedRoots {
            do {
                // First trusting root wins; return C5's path.
                return try await CertificatePathValidator.validate(
                    certificateChain: certificateChain,
                    trustedRootDer: root,
                    expiryPolicy: expiryPolicy
                )
            } catch CoseVerificationFailure.untrustedCertificate {
                continue // this root did not trust the chain; try the next
            }
            // Any other C5 failure propagates unchanged (not caught here).
        }

        // No supplied root trusted the chain.
        throw CoseVerificationFailure.untrustedCertificate
    }
}
