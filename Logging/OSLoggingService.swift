import Logging
import os

public struct OSLoggingService: LoggingService, Sendable {
    
    public static let shared = OSLoggingService()
    
    // Subsystem created to handle larger logging across GDS applications
    private let logger = Logger(subsystem: "uk.gov.onelogin.credential-sharing", category: "CredentialSharing")
    
    // Uses Logging Root Implementation
    // Debug - Does not hold/save logs. Destroyed after session
    // Simple logger
    public func logEvent(_ event: LoggableEvent) {
        logger.debug("\(event.name, privacy: .public)")
    }
    
    // Logger with params
    public func logEvent(_ event: LoggableEvent, parameters: [String: Any]) {
        logger.debug("\(event.name, privacy: .public) \(parameters, privacy: .public)")
    }
}
