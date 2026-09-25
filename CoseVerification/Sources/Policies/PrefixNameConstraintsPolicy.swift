import SwiftASN1
import X509

/// Enforces RFC 5280 §4.2.1.10 NameConstraints on a trusted certificate path, using **prefix**
/// matching for `directoryName` constraints rather than the exact-DN matching performed by the
/// upstream ``X509/RFC5280Policy``.
///
/// This policy exists because the C6 ReaderAuth profile requires that an issuing CA's
/// `directoryName` name constraint be treated as a *prefix* of the presented subject/issuer DN
/// (the constraint's RDN sequence must be a prefix of, or equal to, the presented DN's RDN
/// sequence), compared case-insensitively. Upstream `RFC5280Policy` only accepts an exact DN match,
/// so it would reject legitimate ReaderAuth paths whose leaf DN extends the constrained namespace.
///
/// It is built entirely on the public `X509` / `SwiftASN1` API — it does not depend on any fork of
/// swift-certificates. It is composed for the ReaderAuth role only (see
/// ``CertificateProfileValidator``).
///
/// The algorithm mirrors RFC 5280: starting from the root and moving toward the leaf, for each CA
/// certificate the CA's name constraints are applied to every certificate it issued. As with the
/// upstream policy, a single self-signed certificate briefly "issues itself" so its own constraints
/// are enforced against it.
///
/// **Scope: `directoryName` constraints only.** The GDS ReaderAuth profile constrains issuing CAs
/// via `directoryName` subtrees exclusively, so this policy validates only that name form. Any
/// other constraint form (`dNSName`, `iPAddress`, `uniformResourceIdentifier`, etc.) present on the
/// critical `nameConstraints` extension is treated as unvalidatable and causes the path to be
/// rejected. This is RFC 5280-correct — an unvalidatable constraint on a critical extension MUST
/// cause rejection — and fail-closed by design.
///
/// Fails with the diagnostic ``CertificateProfileReason/nameConstraints``.
struct PrefixNameConstraintsPolicy: VerifierPolicy {
    /// This policy fully handles the (critical) nameConstraints extension, so it declares it here to
    /// prevent the verifier rejecting the path for an unhandled critical extension.
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = [
        .X509ExtensionID.nameConstraints
    ]

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        // Convert the opaque chain to a concrete leaf-first array and run the shared walk. The array
        // form is also the seam used by unit tests, so the exact walk logic is exercised directly.
        Self.evaluate(chain: Array(chain))
    }

    /// Runs the RFC 5280 name-constraints walk over a **leaf-first** certificate array (index 0 is
    /// the leaf, the last element is the root/anchor). This is the core of the policy and the seam
    /// unit tests drive directly, since `UnverifiedCertificateChain` cannot be constructed outside
    /// the X509 module.
    ///
    /// For each issuer (walking from the root toward the leaf) its name constraints are applied to
    /// every certificate below it in the path. A single self-issued certificate enforces its own
    /// constraints against itself.
    static func evaluate(chain: [Certificate]) -> PolicyEvaluationResult {
        // A single certificate: enforce its own constraints on itself (self-issued case).
        if chain.count == 1 {
            return validate(issuedCerts: chain[...], issuer: chain[0])
        }

        // Walk from the root (last element) toward the leaf. `popLast()` yields the current issuer;
        // the certificates still ahead of it in the sequence are the ones it (transitively) issued.
        var issuedCerts = chain[...]
        while let issuer = issuedCerts.popLast(), issuedCerts.count > 0 {
            if case .failsToMeetPolicy(let reason) = validate(issuedCerts: issuedCerts, issuer: issuer) {
                return .failsToMeetPolicy(reason: reason)
            }
        }

        return .meetsPolicy
    }

    /// Applies `issuer`'s name constraints (if any) to every certificate in `issuedCerts`.
    private static func validate(
        issuedCerts: ArraySlice<Certificate>,
        issuer: Certificate
    ) -> PolicyEvaluationResult {
        let maybeConstraints: NameConstraints?
        do {
            maybeConstraints = try issuer.extensions.nameConstraints
        } catch {
            return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
        }

        guard let constraints = maybeConstraints else {
            // No constraints to enforce.
            return .meetsPolicy
        }

        for cert in issuedCerts {
            for name in names(of: cert) {
                if case .failsToMeetPolicy(let reason) =
                    validatePermittedSubtrees(constraints.permittedSubtrees, name) {
                    return .failsToMeetPolicy(reason: reason)
                }
                if case .failsToMeetPolicy(let reason) =
                    validateExcludedSubtrees(constraints.excludedSubtrees, name) {
                    return .failsToMeetPolicy(reason: reason)
                }
            }
        }

        return .meetsPolicy
    }

    // MARK: - Subtree evaluation

    /// Excluded subtrees: if the presented name matches *any* excluded subtree, the name is forbidden.
    ///
    /// Only `directoryName` excluded subtrees are validated. Any other excluded constraint form is
    /// unvalidatable and, being on a critical extension, must cause rejection (RFC 5280).
    private static func validateExcludedSubtrees(
        _ excludedSubtrees: [GeneralName],
        _ name: GeneralName
    ) -> PolicyEvaluationResult {
        for excludedSubtree in excludedSubtrees {
            switch (excludedSubtree, name) {
            case (.directoryName(let constraint), .directoryName(let presentedName)):
                if directoryNameMatchesConstraint(directoryName: presentedName, constraint: constraint) {
                    return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
                }
            case (.directoryName, _):
                // A directoryName excluded subtree with a non-DN presented name: it cannot exclude a
                // name of a different form, so this pairing does not forbid the name.
                continue
            default:
                // Any non-directoryName excluded constraint form is unsupported: we cannot validate
                // it, so we must reject (RFC 5280 — unvalidatable constraint on a critical extension).
                return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
            }
        }
        return .meetsPolicy
    }

    /// Permitted subtrees: for a given name form, if any permitted subtree of that form is present
    /// then the name must match at least one of them.
    ///
    /// Only `directoryName` permitted subtrees are validated. Any other permitted constraint form is
    /// unvalidatable and, being on a critical extension, must cause rejection (RFC 5280).
    private static func validatePermittedSubtrees(
        _ permittedSubtrees: [GeneralName],
        _ name: GeneralName
    ) -> PolicyEvaluationResult {
        var evaluatedAtLeastOneConstraint = false

        for permittedSubtree in permittedSubtrees {
            switch (permittedSubtree, name) {
            case (.directoryName(let constraint), .directoryName(let presentedName)):
                evaluatedAtLeastOneConstraint = true
                if directoryNameMatchesConstraint(directoryName: presentedName, constraint: constraint) {
                    return .meetsPolicy
                }
            case (.directoryName, _):
                // A directoryName permitted subtree with a non-DN presented name: not an evaluated
                // constraint for this name form, so it neither matches nor forces a rejection here.
                continue
            default:
                // Any non-directoryName permitted constraint form is unsupported: reject.
                return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
            }
        }

        // Nothing matched. This is only a violation if at least one permitted subtree of the
        // presented name's form existed.
        guard evaluatedAtLeastOneConstraint else {
            return .meetsPolicy
        }
        return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
    }

    // MARK: - directoryName prefix matching

    /// RFC 5280 prefix matching: the constraint's RDNs must be a prefix of (or equal to) the
    /// presented directory name's RDNs, compared case-insensitively.
    static func directoryNameMatchesConstraint(
        directoryName: DistinguishedName,
        constraint: DistinguishedName
    ) -> Bool {
        let nameRDNs = Array(directoryName)
        let constraintRDNs = Array(constraint)

        guard constraintRDNs.count <= nameRDNs.count else {
            return false
        }

        for index in constraintRDNs.indices {
            let constraintRDN = constraintRDNs[index]
            let nameRDN = nameRDNs[index]
            guard constraintRDN.count == nameRDN.count else { return false }

            for attribute in constraintRDN {
                guard let matchingAttribute = nameRDN.first(where: { $0.type == attribute.type }) else {
                    return false
                }
                if !attributeValuesEqual(attribute.value, matchingAttribute.value) {
                    return false
                }
            }
        }
        return true
    }

    /// Case-insensitive comparison of two RDN attribute values.
    ///
    /// The upstream `RelativeDistinguishedName.Attribute.Value.Storage` enum is not public, so we
    /// compare via the public string projection of the value (which covers PrintableString,
    /// UTF8String and IA5String — the string forms used in practice, and which are compared
    /// case-insensitively here so that e.g. differing case or PrintableString-vs-UTF8String encodings
    /// of the same text are treated as equal). For any value without a string projection we fall back
    /// to exact value equality.
    static func attributeValuesEqual(
        _ lhs: RelativeDistinguishedName.Attribute.Value,
        _ rhs: RelativeDistinguishedName.Attribute.Value
    ) -> Bool {
        // `String(_:)` yields the text for PrintableString / UTF8String / IA5String values and `nil`
        // for values without a string projection. When both sides have a string projection, compare
        // case-insensitively (which also treats differing string encodings of the same text as
        // equal); otherwise fall back to exact value equality.
        if let lhsString = String(lhs), let rhsString = String(rhs) {
            return lhsString.lowercased() == rhsString.lowercased()
        }
        return lhs == rhs
    }

    // MARK: - Name enumeration

    /// The set of names of a certificate to test against constraints: its subject DN plus every
    /// name in its SubjectAlternativeName extension.
    private static func names(of certificate: Certificate) -> [GeneralName] {
        var result: [GeneralName] = [.directoryName(certificate.subject)]
        if let san = try? certificate.extensions.subjectAlternativeNames {
            for name in san {
                result.append(name)
            }
        }
        return result
    }
}
