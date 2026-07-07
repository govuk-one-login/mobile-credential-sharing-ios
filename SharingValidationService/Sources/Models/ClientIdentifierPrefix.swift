import Foundation

public enum ClientIdentifierPrefix: Sendable, Equatable {
    case x509SanDns(identifier: String)
    case x509SanUri(identifier: String)
    case did(identifier: String)
    case redirectUri(identifier: String)
    case verifierAttestation(identifier: String)
    case preRegistered(fullClientID: String)

    /// The verifier identifier carried by the prefix — the DNS name, URI, DID, or full client ID
    /// depending on the case. Suitable for surfacing the verifier's identity to the user.
    public var identifier: String {
        switch self {
        case let .x509SanDns(identifier),
             let .x509SanUri(identifier),
             let .did(identifier),
             let .redirectUri(identifier),
             let .verifierAttestation(identifier),
             let .preRegistered(identifier):
            return identifier
        }
    }

    static func parse(clientID: String) -> ClientIdentifierPrefix {
        let knownPrefixes: [(prefix: String, factory: (String) -> ClientIdentifierPrefix)] = [
            ("x509_san_dns:", { .x509SanDns(identifier: $0) }),
            ("x509_san_uri:", { .x509SanUri(identifier: $0) }),
            ("did:", { .did(identifier: $0) }),
            ("redirect_uri:", { .redirectUri(identifier: $0) }),
            ("verifier_attestation:", { .verifierAttestation(identifier: $0) })
        ]

        for (prefix, factory) in knownPrefixes where clientID.hasPrefix(prefix) {
            let identifier = String(clientID.dropFirst(prefix.count))
            return factory(identifier)
        }

        return .preRegistered(fullClientID: clientID)
    }
}
