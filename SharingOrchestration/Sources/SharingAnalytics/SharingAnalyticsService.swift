import Foundation

public protocol SharingAnalyticsService {
    func trackScreen(_ screen: SharingScreen, with errorDescription: String?)
    func trackEvent(_ event: SharingEvent)
}

public extension SharingAnalyticsService {
    func trackScreen(_ screen: SharingScreen) {
        trackScreen(screen, with: nil)
    }
}

/// A localisation key plus the analytics-only literals substituted into it.
/// Shared by screens and events so the logged copy matches the on-screen copy
/// while keeping verifier-specific values (e.g. the real DVS name) out of
/// analytics.
public struct AnalyticsCopy {
    public let key: String
    /// Positional substitutions for the template's placeholders. Empty when the
    /// copy has no placeholders.
    public let substitutions: [String]

    public init(_ key: String, substitutions: [String] = []) {
        self.key = key
        self.substitutions = substitutions
    }
}

/// A screen's position in the flow. Raw values are the logged taxonomy strings.
public enum ScreenClass: String, Equatable {
    case readiness = "READINESS"
    case progress = "PROGRESS"
    case engagement = "ENGAGEMENT"
    case consent = "CONSENT"
    case resolution = "RESOLUTION"
    case error = "ERROR"
}

public enum SharingScreen: Equatable {
    case getReadyToShare
    case turnOnBluetooth
    case gettingListOfDetails
    case sharingYourDetails
    case qrCode
    case consent
    case moreAboutDVS
    case detailsShared
    case genericError

    // TODO: DCMAW-17154 Add all other specific errors, then remove this legacy screen
    case error

    /// The firebase screen id
    public var id: String { details.id }

    /// The screen's analytics copy: its localisation key plus any analytics-only
    /// substitutions for the template's placeholders.
    public var title: AnalyticsCopy { details.title }

    /// The current presentation position in the flow
    public var screenClass: ScreenClass { details.screenClass }
}

private extension SharingScreen {
    /// Everything analytics needs to know about a screen, defined once per case.
    struct Details {
        let id: String
        let title: AnalyticsCopy
        let screenClass: ScreenClass
    }

    var details: Details {
        switch self {
        case .getReadyToShare:
            Details(
                id: "3f5c1d0b-8068-4e19-8300-37f7bb468ff5",
                title: AnalyticsCopy("getReadyToShareTitle"),
                screenClass: .readiness
            )
        case .turnOnBluetooth:
            Details(
                id: "d64962b9-def5-4b13-9c3c-128d51353fe7",
                title: AnalyticsCopy("turnOnBluetoothTitle"),
                screenClass: .readiness
            )
        case .gettingListOfDetails:
            Details(
                id: "06328966-cd42-49c4-a573-9140ace45297",
                title: AnalyticsCopy("progressGettingListOfDetails"),
                screenClass: .progress
            )
        case .sharingYourDetails:
            Details(
                id: "aedea082-0575-4f4e-babf-b2221d74756f",
                title: AnalyticsCopy("progressSharingYourDetails"),
                screenClass: .progress
            )
        case .qrCode:
            Details(
                id: "29fd14a3-4390-4939-9d57-d9fe8cf61811",
                title: AnalyticsCopy("qrCodeTitle"),
                screenClass: .engagement
            )
        case .consent:
            Details(
                id: "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e",
                title: AnalyticsCopy("consentTitle"),
                screenClass: .consent
            )
        case .moreAboutDVS:
            Details(
                id: "288470f5-8bdb-43cf-8cd7-38bcd241413b",
                title: AnalyticsCopy("moreAboutDVSTitle", substitutions: ["dvsAnalyticsName"]),
                screenClass: .consent
            )
        case .detailsShared:
            Details(
                id: "c2ccd487-c0e0-4ef8-943b-c555c4856a2c",
                title: AnalyticsCopy("detailsSharedTitle"),
                screenClass: .resolution
            )
        case .genericError:
            Details(
                id: "9bf821af-e8ff-41cf-a311-4b6cec989315",
                title: AnalyticsCopy("genericErrorTitle"),
                screenClass: .resolution
            )
        case .error:
            // Legacy placeholder, used by `ErrorViewController`
            Details(
                id: "0000",
                title: AnalyticsCopy("error"),
                screenClass: .error
            )
        }
    }
}

public enum SharingEvent: String {
    case cancel
    case close
    case getReadyToShareFindOutHowButton
    case getReadyToShareAllowBluetoothButton
    case goBackToDocumentsButton
    case consentAgreeButton
    case consentCancelButton
    case consentReadAboutButton
    case dvsPrivacyNotice
    case stopTheCheckButton
    case continueWithTheCheckButton

    /// The button's analytics copy: its localisation key plus any analytics-only
    /// substitutions. Reuses the on-screen key where the copy matches, so there
    /// is a single source of truth; the agree button is the exception, using a
    /// dedicated key whose copy intentionally omits the item count.
    public var title: AnalyticsCopy {
        switch self {
        case .consentAgreeButton:
            AnalyticsCopy("consentAgreeButtonAnalytics")
        case .consentCancelButton:
            AnalyticsCopy("cancelAndGoBackButton")
        case .consentReadAboutButton, .dvsPrivacyNotice:
            AnalyticsCopy(rawValue, substitutions: ["dvsAnalyticsName"])
        case .cancel, .close,
             .getReadyToShareFindOutHowButton, .getReadyToShareAllowBluetoothButton,
             .goBackToDocumentsButton, .stopTheCheckButton, .continueWithTheCheckButton:
            AnalyticsCopy(rawValue)
        }
    }
}
