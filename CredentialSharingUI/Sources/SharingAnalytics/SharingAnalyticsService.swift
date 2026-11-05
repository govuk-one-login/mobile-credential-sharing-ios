import Foundation

public protocol SharingAnalyticsService {
    func trackScreen(_ screen: SharingScreen)
    func trackEvent(_ event: SharingEvent)
}

public enum SharingScreen: Equatable {
    case getReadyToShare

    public var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        }
    }
    
    /// The English title copy, resolved from the SDK's own string catalogue.
    public var englishTitle: String {
        var titleKey: String.LocalizationValue
        
        switch self {
        case .getReadyToShare:
            titleKey = "getReadyToShareTitle"
        }
        
        return String(
            localized: LocalizedStringResource(
                titleKey,
                locale: Locale(identifier: "en"),
                bundle: .module
            )
        )
    }
    
    public var screenClass: String {
        switch self {
        case .getReadyToShare:
            "READINESS"
        }
    }
}

public enum SharingEvent: String {
    case cancel
    case getReadyToShareFindOutHowButton
    case getReadyToShareAllowBluetoothButton

    /// The English button copy, resolved from the SDK's own string catalogue.
    public var englishTitle: String {
        String(
            localized: LocalizedStringResource(
                String.LocalizationValue(rawValue),
                locale: Locale(identifier: "en"),
                bundle: .module
            )
        )
    }
}
