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
    case readerAuthError
    case unfulfillableRequest
    
    // TODO: DCMAW-17154 Add all other specific errors, then remove this legacy screen
    case error
    
    /// The firebase screen id
    public var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .turnOnBluetooth:
            "d64962b9-def5-4b13-9c3c-128d51353fe7"
        case .gettingListOfDetails:
            "06328966-cd42-49c4-a573-9140ace45297"
        case .sharingYourDetails:
            "aedea082-0575-4f4e-babf-b2221d74756f"
        case .qrCode:
            "29fd14a3-4390-4939-9d57-d9fe8cf61811"
        case .consent:
            "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e"
        case .moreAboutDVS:
            "288470f5-8bdb-43cf-8cd7-38bcd241413b"
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        case .genericError:
            "9bf821af-e8ff-41cf-a311-4b6cec989315"
        case .readerAuthError:
            "d3e44133-024c-4ce8-84bf-7bed9c01ff96"
        case .unfulfillableRequest:
            "1c5c61b3-b8d4-4355-9be3-b26440a43b3f"
        case .error:
            // Legacy placeholder, used by `ErrorViewController`
            "0000"
        }
    }
    
    /// The screen's analytics copy: its localisation key plus any analytics-only
    /// substitutions for the template's placeholders.
    public var title: AnalyticsCopy {
        switch self {
        case .getReadyToShare:
            AnalyticsCopy("getReadyToShareTitle")
        case .turnOnBluetooth:
            AnalyticsCopy("turnOnBluetoothTitle")
        case .gettingListOfDetails:
            AnalyticsCopy("progressGettingListOfDetails")
        case .sharingYourDetails:
            AnalyticsCopy("progressSharingYourDetails")
        case .qrCode:
            AnalyticsCopy("qrCodeTitle")
        case .consent:
            AnalyticsCopy("consentTitle")
        case .moreAboutDVS:
            AnalyticsCopy("moreAboutDVSTitle", substitutions: ["dvsAnalyticsName"])
        case .detailsShared:
            AnalyticsCopy("detailsSharedTitle")
        case .genericError:
            AnalyticsCopy("genericErrorTitle")
        case .readerAuthError:
            AnalyticsCopy("readerAuthErrorTitle")
        case .unfulfillableRequest:
            AnalyticsCopy("unfulfillableRequestTitle")
        case .error:
            AnalyticsCopy("error")
        }
    }

    /// The current presentation position in the flow
    public var screenClass: String {
        switch self {
        case .getReadyToShare, .turnOnBluetooth:
            "READINESS"
        case .gettingListOfDetails, .sharingYourDetails:
            "PROGRESS"
        case .qrCode:
            "ENGAGEMENT"
        case .consent, .moreAboutDVS:
            "CONSENT"
        case .detailsShared, .genericError, .readerAuthError, .unfulfillableRequest:
            "RESOLUTION"
        case .error:
            "ERROR"
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
        case .cancel:
            AnalyticsCopy("cancel")
        case .close:
            AnalyticsCopy("close")
        case .getReadyToShareFindOutHowButton:
            AnalyticsCopy("getReadyToShareFindOutHowButton")
        case .getReadyToShareAllowBluetoothButton:
            AnalyticsCopy("getReadyToShareAllowBluetoothButton")
        case .goBackToDocumentsButton:
            AnalyticsCopy("goBackToDocumentsButton")
        case .consentAgreeButton:
            AnalyticsCopy("consentAgreeButtonAnalytics")
        case .consentCancelButton:
            AnalyticsCopy("cancelAndGoBackButton")
        case .consentReadAboutButton:
            AnalyticsCopy("consentReadAboutButton", substitutions: ["dvsAnalyticsName"])
        case .dvsPrivacyNotice:
            AnalyticsCopy("dvsPrivacyNotice", substitutions: ["dvsAnalyticsName"])
        case .stopTheCheckButton:
            AnalyticsCopy("stopTheCheckButton")
        case .continueWithTheCheckButton:
            AnalyticsCopy("continueWithTheCheckButton")
        }
    }
}
