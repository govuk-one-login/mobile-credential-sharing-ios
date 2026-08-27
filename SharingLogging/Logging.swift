import os

public struct Logging: Sendable {
    
    public static let shared = Logging()
    
    // Subsystem created to handle larger logging across GDS applications
    private let logger = Logger(subsystem: "uk.gov.onelogin.credential-sharing", category: "CredentialSharing")
    
    // Uses Logging Root Implementation
    // Debug - Does not hold/save logs. Destroyed after session
    // Simple logger
    public func log(_ event: String) {
        logger.debug("\(event, privacy: .public)")
    }

}
