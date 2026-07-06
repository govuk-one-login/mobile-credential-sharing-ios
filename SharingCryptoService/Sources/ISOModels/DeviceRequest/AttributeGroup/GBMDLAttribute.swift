/// A type-safe representation of UK domestic namespace data element identifiers
/// from the org.iso.18013.5.1.GB namespace.
public enum GBMDLAttribute: String, CaseIterable, Equatable, Hashable, Sendable {
    case welshLicence = "welsh_licence"
    case title = "title"
    case provisionalDrivingPrivileges = "provisional_driving_privileges"

    /// The data element identifier string.
    public var identifier: String { rawValue }
}
