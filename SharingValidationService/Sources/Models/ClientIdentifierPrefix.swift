import Foundation

public enum ClientIdentifierPrefix: Sendable, Equatable {
    case x509SanDns(identifier: String)
    case x509SanUri(identifier: String)
    case did(identifier: String)
    case redirectUri(identifier: String)
    case verifierAttestation(identifier: String)
    case preRegistered(fullClientID: String)

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
