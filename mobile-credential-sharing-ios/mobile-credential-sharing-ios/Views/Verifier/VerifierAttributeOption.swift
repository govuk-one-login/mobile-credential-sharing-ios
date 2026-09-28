import Foundation
import SharingCryptoService

/// The attribute-group presets selectable in the Verifier test app.
///
/// Ported from the Android `VerifierAttributeOption` enum. Each option maps to a concrete
/// ``AttributeGroup`` requested for the session. Selection is single-choice via a drop-down.
enum VerifierAttributeOption: CaseIterable {
    case portraitAndAgeOver21
    case portraitNameRetainAndAgeOver18
    case nameMissingPortrait
    case nameTitleRetainAndAgeOver23

    /// The option selected by default before any user interaction.
    static let `default`: VerifierAttributeOption = .portraitAndAgeOver21

    /// Human-readable label shown in the selection UI.
    var displayName: String {
        switch self {
        case .portraitAndAgeOver21:
            return "Photo and Age Over 21"
        case .portraitNameRetainAndAgeOver18:
            return "Photo and Name (Retain) and Age Over 18"
        case .nameMissingPortrait:
            return "Name (Missing Photo)"
        case .nameTitleRetainAndAgeOver23:
            return "Name + Title (Retain) and Age Over 23"
        }
    }

    /// The concrete `AttributeGroup` requested for this option.
    var attributeGroup: AttributeGroup? {
        switch self {
        case .portraitAndAgeOver21:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .portrait, intentToRetain: false),
                    .init(attribute: .ageOver(21), intentToRetain: false)
                ]
            )
        case .portraitNameRetainAndAgeOver18:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .portrait, intentToRetain: true),
                    .init(attribute: .givenName, intentToRetain: true),
                    .init(attribute: .familyName, intentToRetain: true),
                    .init(attribute: .ageOver(18), intentToRetain: false)
                ]
            )
        case .nameMissingPortrait:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .givenName, intentToRetain: false)
                ]
            )
        case .nameTitleRetainAndAgeOver23:
            return AttributeGroup(
                mdlAttributes: [
                    .init(attribute: .givenName, intentToRetain: true),
                    .init(attribute: .ageOver(23), intentToRetain: false)
                ],
                gbMdlAttributes: [
                    .init(attribute: .title, intentToRetain: true)
                ]
            )
        }
    }
}
