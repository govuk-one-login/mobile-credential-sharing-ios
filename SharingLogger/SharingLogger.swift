import os

public enum Logger: Sendable {
    // Subsystem created to handle larger logging across GDS applications
    private static let logger = os.Logger(
        subsystem: "uk.gov.onelogin.credential-sharing",
        category: "CredentialSharing"
    )
    
    // Uses Logging Root Implementation
    // Debug - Does not hold/save logs. Destroyed after session
    // Simple logger
    public static func log(
        _ message: String,
        level: OSLogType = .debug
    ) {
        logger.log(level: level, "\(message, privacy: .public)")
    }
}
