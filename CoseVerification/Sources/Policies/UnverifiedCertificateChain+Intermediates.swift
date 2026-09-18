import X509

extension UnverifiedCertificateChain {
    /// The intermediate certificates only: the chain with the leaf (first) and the trusted root
    /// (last) removed.
    ///
    /// The ``X509/Verifier`` builds the chain as `[leaf, …intermediates…, root]`, appending the
    /// matched trusted root before policy evaluation. Dropping the first element removes the
    /// end-entity; dropping the last removes the trusted root. The remainder is exactly the set of
    /// intermediate certificates that the intermediate-specific profile rules apply to.
    ///
    /// A two-element chain (`[leaf, root]`, i.e. a leaf issued directly by the root) yields an empty
    /// array, which is correct: there are no intermediates to check.
    var intermediates: [Certificate] {
        Array(dropFirst().dropLast())
    }
}
