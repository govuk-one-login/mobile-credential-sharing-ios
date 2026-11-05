import GDSAnalytics
import Logging
import CredentialSharingUI
import Foundation

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
            titleKey: screen.englishTitle
        )
        
        analyticsService.trackScreen(screenView, parameters: screenView.parameters)
    }
    
    func trackEvent(_ event: SharingEvent) {
        let buttonEvent = ButtonEvent(textKey: event.englishTitle)
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
