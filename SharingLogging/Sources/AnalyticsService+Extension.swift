import GDSAnalytics
import Logging

extension AnalyticsService {
    public func logEvent(_ event: Event) {
        logEvent(event.name, parameters: event.parameters)
    }
    
    public func trackScreen<T: CustomStringConvertible>(_ screen: ScreenView<T>) {
        trackScreen(screen, parameters: screen.parameters)
    }
    
    public func trackScreen<T: CustomStringConvertible>(_ screen: ErrorScreenView<T>) {
        trackScreen(screen, parameters: screen.parameters)
    }
}

extension EventName: @retroactive LoggableEvent { }

extension ScreenView: @retroactive LoggableScreen
where Screen: GDSAnalytics.ScreenType & CustomStringConvertible {
    public var name: String {
        title
    }
    
    public var type: Screen {
        screen
    }
}

extension ErrorScreenView: @retroactive LoggableScreen
where Screen: GDSAnalytics.ScreenType & CustomStringConvertible {
    public var name: String {
        title
    }
    
    public var type: Screen {
        screen
    }
}
