/// A type-safe representation of supported UK mDL data element identifiers
/// from the standard ISO 18013-5.1 namespace (org.iso.18013.5.1).
public enum MDLAttribute: Equatable, Hashable, Sendable {
    case familyName
    case givenName
    case birthDate
    case issueDate
    case expiryDate
    case issuingCountry
    case issuingAuthority
    case documentNumber
    case portrait
    case birthPlace
    case drivingPrivileges
    case unDistinguishingSign
    case residentAddress
    case residentPostalCode
    case residentCity
    /// age_over_NN where NN is a value between 0 and 99.
    case ageOver(Int)

    /// The data element identifier string.
    public var identifier: String {
        switch self {
        case .familyName: return "family_name"
        case .givenName: return "given_name"
        case .birthDate: return "birth_date"
        case .issueDate: return "issue_date"
        case .expiryDate: return "expiry_date"
        case .issuingCountry: return "issuing_country"
        case .issuingAuthority: return "issuing_authority"
        case .documentNumber: return "document_number"
        case .portrait: return "portrait"
        case .birthPlace: return "birth_place"
        case .drivingPrivileges: return "driving_privileges"
        case .unDistinguishingSign: return "un_distinguishing_sign"
        case .residentAddress: return "resident_address"
        case .residentPostalCode: return "resident_postal_code"
        case .residentCity: return "resident_city"
        case .ageOver(let age): return "age_over_\(age)"
        }
    }
}
