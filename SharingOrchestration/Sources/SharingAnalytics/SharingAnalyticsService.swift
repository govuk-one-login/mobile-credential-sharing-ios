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

public enum SharingScreen: Equatable {
    case getReadyToShare
    case turnOnBluetooth
    case gettingListOfDetails
    case sharingYourDetails
    case qrCode
    case consent
    case detailsShared
    case genericError
    
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
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        case .genericError:
            "9bf821af-e8ff-41cf-a311-4b6cec989315"
        case .error:
            // Legacy placeholder, used by `ErrorViewController`
            "0000"
        }
    }
    
    /// The titleKey String
    public var titleKey: String {
        switch self {
        case .getReadyToShare:
            "getReadyToShareTitle"
        case .turnOnBluetooth:
            "turnOnBluetoothTitle"
        case .gettingListOfDetails:
            "progressGettingListOfDetails"
        case .sharingYourDetails:
            "progressSharingYourDetails"
        case .qrCode:
            "qrCodeTitle"
        case .consent:
            "consentTitle"
        case .detailsShared:
            "detailsSharedTitle"
        case .genericError:
            "genericErrorTitle"
        case .error:
            "error"
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
        case .consent:
            "CONSENT"
        case .detailsShared, .genericError:
            "RESOLUTION"
        case .error:
            "ERROR"
        }
    }
}

public enum SharingEvent: String {
    case cancel
    case getReadyToShareFindOutHowButton
    case getReadyToShareAllowBluetoothButton
    case goBackToDocumentsButton
    case consentAgreeButton
    case consentCancelButton
    case consentReadAboutButton
    
    public var analyticsTextKey: String {
        switch self {
        case .consentReadAboutButton:
            "consentReadAboutButtonAnalytics"
        case .consentAgreeButton:
            "consentAgreeButtonAnalytics"
        case .consentCancelButton:
            "consentCancelButtonAnalytics"
        default:
            rawValue
        }
    }
}
