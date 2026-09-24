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
/// Fails with the diagnostic ``CertificateProfileReason/nameConstraints``.
struct PrefixNameConstraintsPolicy: VerifierPolicy {
    /// This policy fully handles the (critical) nameConstraints extension, so it declares it here to
    /// prevent the verifier rejecting the path for an unhandled critical extension.
    let verifyingCriticalExtensions: [ASN1ObjectIdentifier] = [
        .X509ExtensionID.nameConstraints
    ]

    func chainMeetsPolicyRequirements(chain: UnverifiedCertificateChain) -> PolicyEvaluationResult {
        // A single certificate: enforce its own constraints on itself (self-issued case).
        if chain.count == 1 {
            return Self.validate(issuedCerts: chain[...], issuer: chain.first!)
        }

        // Walk from the root (last element) toward the leaf. `popLast()` yields the current issuer;
        // the certificates still ahead of it in the sequence are the ones it (transitively) issued.
        var issuedCerts = chain[...]
        while let issuer = issuedCerts.popLast(), issuedCerts.count > 0 {
            if case .failsToMeetPolicy(let reason) = Self.validate(issuedCerts: issuedCerts, issuer: issuer) {
                return .failsToMeetPolicy(reason: reason)
            }
        }

        return .meetsPolicy
    }

    /// Applies `issuer`'s name constraints (if any) to every certificate in `issuedCerts`.
    private static func validate(
        issuedCerts: UnverifiedCertificateChain.SubSequence,
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
            case (.dnsName(let constraint), .dnsName(let presentedName)):
                if dnsNameMatchesConstraint(dnsName: presentedName, constraint: constraint) {
                    return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
                }
            case (.uniformResourceIdentifier(let constraint), .uniformResourceIdentifier(let presentedName)):
                if uriNameMatchesConstraint(uriName: presentedName, constraint: constraint) {
                    return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
                }
            case (.directoryName, _), (.dnsName, _), (.uniformResourceIdentifier, _):
                // Supported constraint type, but the presented name is a different form.
                // A directoryName presented against a non-DN exclusion is treated as excluded.
                if case .directoryName = name {
                    return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
                }
                continue
            default:
                // Unsupported constraint form: we cannot validate it, so we must reject (RFC 5280).
                return .failsToMeetPolicy(reason: CertificateProfileReason.nameConstraints)
            }
        }
        return .meetsPolicy
    }

    /// Permitted subtrees: for a given name form, if any permitted subtree of that form is present
    /// then the name must match at least one of them.
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
            case (.dnsName(let constraint), .dnsName(let presentedName)):
                evaluatedAtLeastOneConstraint = true
                if dnsNameMatchesConstraint(dnsName: presentedName, constraint: constraint) {
                    return .meetsPolicy
                }
            case (.uniformResourceIdentifier(let constraint), .uniformResourceIdentifier(let presentedName)):
                evaluatedAtLeastOneConstraint = true
                if uriNameMatchesConstraint(uriName: presentedName, constraint: constraint) {
                    return .meetsPolicy
                }
            case (.directoryName, _), (.dnsName, _), (.uniformResourceIdentifier, _):
                // Supported constraint type, but the presented name is a different form. A
                // directoryName presented against a non-DN permitted subtree counts as an evaluated
                // constraint that did not match.
                if case .directoryName = name {
                    evaluatedAtLeastOneConstraint = true
                }
                continue
            default:
                // Unsupported constraint form: reject.
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

    // MARK: - Other name forms (semantics preserved from upstream / the fork)

    private static func dnsNameMatchesConstraint(dnsName: String, constraint: String) -> Bool {
        // RFC 5280 dNSName constraint: case-insensitive suffix match on label boundaries.
        // An empty constraint matches everything.
        let name = dnsName.lowercased()
        let constraint = constraint.lowercased()
        if constraint.isEmpty { return true }
        if name == constraint { return true }
        // The constraint matches if it is a suffix of the name at a label boundary.
        let dottedConstraint = constraint.hasPrefix(".") ? constraint : "." + constraint
        return name.hasSuffix(dottedConstraint)
    }

    private static func uriNameMatchesConstraint(uriName: String, constraint: String) -> Bool {
        // RFC 5280 URI constraint applies to the host portion; we mirror dNSName host semantics.
        let host = Self.uriHost(uriName).lowercased()
        let constraint = constraint.lowercased()
        if constraint.isEmpty { return true }
        if host == constraint { return true }
        let dottedConstraint = constraint.hasPrefix(".") ? constraint : "." + constraint
        return host.hasSuffix(dottedConstraint)
    }

    /// Extracts the host component of a URI for host-based constraint matching.
    private static func uriHost(_ uri: String) -> String {
        var remainder = Substring(uri)
        if let schemeRange = remainder.range(of: "://") {
            remainder = remainder[schemeRange.upperBound...]
        }
        if let slash = remainder.firstIndex(of: "/") {
            remainder = remainder[..<slash]
        }
        if let at = remainder.lastIndex(of: "@") {
            remainder = remainder[remainder.index(after: at)...]
        }
        if let colon = remainder.firstIndex(of: ":") {
            remainder = remainder[..<colon]
        }
        return String(remainder)
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
