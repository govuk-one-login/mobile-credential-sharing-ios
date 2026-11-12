import CredentialSharingUI
import Foundation
import GDSAnalytics
import Logging

struct GDSSharingAnalyticsAdapter: SharingAnalyticsService {
    var analyticsService: AnalyticsService
   
    init(analyticsService: AnalyticsService) {
        self.analyticsService = analyticsService.addingAdditionalParameters(
            ["taxonomy_level3": "proximity sharing"])
    }
    
    func trackScreen(_ screen: SharingScreen, with errorDescription: String?) {
        var loggableScreen: any LoggableScreen
        var parameters: [String: String]
        if let errorDescription {
            let errorScreenView = ErrorScreenView(
                id: screen.id,
                screen: screen,
                titleKey: screen.title.key,
                reason: errorDescription
            )
            loggableScreen = errorScreenView
            parameters = errorScreenView.parameters
        } else {
            let screenView = ScreenView(
                id: screen.id,
                screen: screen,
                titleKey: screen.title.key,
                variableKeys: screen.title.substitutions,
                bundle: SharingBundle.module
            )
            loggableScreen = screenView
            parameters = screenView.parameters
        }
        
        analyticsService.trackScreen(loggableScreen, parameters: parameters)
    }
    
    func trackEvent(_ event: SharingEvent) {
        let buttonEvent = ButtonEvent(textKey: event.rawValue)
        analyticsService.logEvent(buttonEvent)
    }
}

extension SharingScreen: GDSAnalytics.ScreenType {
    public var name: String {
        screenClass
    }
}

extension ButtonEvent: @retroactive LoggableEvent {
    public var name: String {
        text
    }
}
