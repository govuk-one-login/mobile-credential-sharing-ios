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
    
    func trackScreen(_ screen: SharingScreen) {
        let screenView = ScreenView(
            id: screen.id,
            screen: screen,
            titleKey: screen.title,
            bundle: SharingBundle.module
        )
        
        analyticsService.trackScreen(screenView, parameters: screenView.parameters)
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
