import SwiftASN1
import X509

/// A ``VerifierPolicy`` that declares a fixed set of critical-extension OIDs as *handled*, so the
/// ``X509/Verifier`` does not reject a chain purely because a certificate carries one of them as a
/// critical extension (for example a critical `KeyUsage` or `BasicConstraints`).
///
/// This policy performs no checking of its own — the critical-extension *allow-list* and the
/// unique-OID rule are enforced by ``X509/Verifier/validate(leaf:intermediates:)``. Its sole
/// purpose is to satisfy the verifier's requirement that every critical extension be understood by
/// the policy set, without weakening that allow-list: only the same OIDs the validator permits are
/// declared here.
struct AllowListedCriticalExtensionsPolicy: VerifierPolicy {

    let verifyingCriticalExtensions: [ASN1ObjectIdentifier]

    init(handledExtensionOIDs: [ASN1ObjectIdentifier]) {
        self.verifyingCriticalExtensions = handledExtensionOIDs
    }

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) async -> PolicyEvaluationResult {
        // Always `.meetsPolicy`: this policy is a declaration, not a check. Listing an OID in
        // `verifyingCriticalExtensions` tells the verifier that this policy *handles* that critical
        // extension, which suppresses the verifier's default "unhandled critical extension"
        // rejection for it. The actual gating — rejecting critical OIDs outside the allow-list and
        // enforcing the unique-OID rule — is done by the verifier itself, not here. There is no
        // per-chain condition under which this policy should fail, so it unconditionally passes.
        .meetsPolicy
    }
}
