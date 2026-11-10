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
    case consent
    case moreAboutDVS
    case detailsShared
    
    // TODO: DCMAW-24162 Add all other specific errors
    case error

    /// The firebase screen id
    public var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .turnOnBluetooth:
            "d64962b9-def5-4b13-9c3c-128d51353fe7"
        case .consent:
            "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e"
        case .moreAboutDVS:
            "288470f5-8bdb-43cf-8cd7-38bcd241413b"
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        case .error:
            // TODO: DCMAW-24162 Split error screens out
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
        case .consent:
            "agreeToShareTitle"
        case .moreAboutDVS:
            "moreAboutDVSTitle"
        case .detailsShared:
            "detailsSharedTitle"
        case .error:
            "error"
        }
    }
    
    /// The current presentation position in the flow
    public var screenClass: String {
        switch self {
        case .getReadyToShare, .turnOnBluetooth:
            "READINESS"
        case .consent, .moreAboutDVS:
            "CONSENT"
        case .detailsShared:
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
    case detailsSharedGoBackButton
    case consentAgreeButton
    case consentCancelButton
    case consentReadAboutButton
    case dvsPrivacyPolicyLink
}

public enum SharingBundle {
    public static var module: Bundle { .module }
}
