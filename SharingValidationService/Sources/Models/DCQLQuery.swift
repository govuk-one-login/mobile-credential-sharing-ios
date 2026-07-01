import Foundation

public struct DCQLQuery: Sendable, Equatable, Decodable {
    public let credentials: [CredentialQuery]
    public let credentialSets: [CredentialSetQuery]?

    public init(credentials: [CredentialQuery], credentialSets: [CredentialSetQuery]?) {
        self.credentials = credentials
        self.credentialSets = credentialSets
    }

    enum CodingKeys: String, CodingKey {
        case credentials
        case credentialSets = "credential_sets"
    }
}

public struct CredentialQuery: Sendable, Equatable, Decodable {
    public let id: String
    public let format: String
    public let meta: CredentialMeta?
    public let claims: [ClaimQuery]?
    public let claimSets: [[String]]?

    public init(
        id: String,
        format: String,
        meta: CredentialMeta?,
        claims: [ClaimQuery]?,
        claimSets: [[String]]?
    ) {
        self.id = id
        self.format = format
        self.meta = meta
        self.claims = claims
        self.claimSets = claimSets
    }

    enum CodingKeys: String, CodingKey {
        case id
        case format
        case meta
        case claims
        case claimSets = "claim_sets"
    }
}

public struct CredentialMeta: Sendable, Equatable, Decodable {
    public let doctypeValue: String?

    public init(doctypeValue: String?) {
        self.doctypeValue = doctypeValue
    }

    enum CodingKeys: String, CodingKey {
        case doctypeValue = "doctype_value"
    }
}

public struct ClaimQuery: Sendable, Equatable, Decodable {
    public let id: String?
    public let path: [String]
    public let values: [ClaimValue]?

    public init(id: String?, path: [String], values: [ClaimValue]?) {
        self.id = id
        self.path = path
        self.values = values
    }
}

public enum ClaimValue: Sendable, Equatable, Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                ClaimValue.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported claim value type"
                )
            )
        }
    }
}

public struct CredentialSetQuery: Sendable, Equatable, Decodable {
    public let options: [[String]]
    public let required: Bool?

    public init(options: [[String]], required: Bool?) {
        self.options = options
        self.required = required
    }
}
