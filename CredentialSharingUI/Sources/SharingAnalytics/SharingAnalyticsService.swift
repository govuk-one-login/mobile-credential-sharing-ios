import Foundation
import SharingOrchestration

public protocol SharingAnalyticsService {
    func trackScreen(_ screen: SharingScreen)
    func trackErrorScreen(_ screen: SharingScreen, with error: SessionError)
    func trackEvent(_ event: SharingEvent)
}

public enum SharingScreen: Equatable {
    case getReadyToShare
    case turnOnBluetooth
    case detailsShared
    
    // TODO: DCMAW-24162 Add all other specific errors
    case error

    public var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .turnOnBluetooth:
            "d64962b9-def5-4b13-9c3c-128d51353fe7"
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        case .error:
            // TODO: DCMAW-24162 Split error screens out
            "0000"
        }
    }
    
    /// The English title copy, resolved from the SDK's own string catalogue.
    public var title: String {
        switch self {
        case .getReadyToShare:
            "getReadyToShareTitle"
        case .turnOnBluetooth:
            "turnOnBluetoothTitle"
        case .detailsShared:
            "detailsSharedTitle"
        case .error:
            "error"
        }
    }
    
    public var screenClass: String {
        switch self {
        case .getReadyToShare, .turnOnBluetooth:
            "READINESS"
        case .detailsShared:
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
    case detailsSharedGoBackButton
}

public enum SharingBundle {
    public static var module: Bundle { .module }
}
