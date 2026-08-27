import Foundation
import Logging
import SharingLogging

/// Debug logging service that prints events and errors to the console in DEBUG mode.
final class DebugLoggingService: AnalyticsService {
    var analyticsPreferenceStore: AnalyticsPreferenceStore
    var additionalParameters: [String: Any] = [:]
    
    init(analyticsPreferenceStore: AnalyticsPreferenceStore = UserDefaultsPreferenceStore()) {
        self.analyticsPreferenceStore = analyticsPreferenceStore
    }
    
    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self {
        self.additionalParameters.merge(additionalParameters) { existing, _ in existing }
        return self
    }
    
    func trackScreen(_ screen: any LoggableScreen, parameters: [String: Any]) {
        #if DEBUG
        Logging.shared.log("[DebugLoggingService] Screen: \(screen.name), Type: \(screen.type), Parameters: \(parameters)")
        #endif
    }
    
    func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        #if DEBUG
        Logging.shared.log("[DebugLoggingService] Event: \(event.name), Parameters: \(parameters)")
        #endif
    }
    
    func logCrash(_ crash: NSError) {
        #if DEBUG
        Logging.shared.log("[DebugLoggingService] Crash: \(crash)")
        #endif
    }
    
    func logCrash(_ crash: Error) {
        #if DEBUG
        Logging.shared.log("[DebugLoggingService] Crash: \(crash)")
        #endif
    }
}
