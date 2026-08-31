import os

/// Central diagnostic logger for the credential sharing SDK.
///
/// Messages are emitted to the unified logging system under a fixed
/// subsystem and category. Unified logging may retain entries in memory
/// or persistent storage independently of the SDK session, and public
/// messages can be read via live log streams.
///
/// The message privacy defaults to `.public`. Callers are responsible for
/// passing only diagnostic text that is safe to expose. When a message must
/// include sensitive material (credential, request, response, transcript,
/// key, nonce, IV, signature, or identifier values), pass `privacy: .private`
/// or, preferably, log only safe metadata such as operation name, status,
/// or byte count.
public enum Logger {
    /// Controls how the interpolated message is treated by unified logging.
    public enum Privacy {
        /// The message is readable in log output. Use only for text that is
        /// safe to expose.
        case `public`
        /// The message is redacted in log output unless the reading device is
        /// configured to reveal private data. Use for sensitive values.
        case `private`
    }

    // Subsystem created to handle larger logging across GDS applications
    private static let logger = os.Logger(
        subsystem: "uk.gov.onelogin.credential-sharing",
        category: "CredentialSharing"
    )

    public static func log(
        _ message: String,
        level: OSLogType = .debug,
        privacy: Privacy = .public
    ) {
        switch privacy {
        case .public:
            logger.log(level: level, "\(message, privacy: .public)")
        case .private:
            logger.log(level: level, "\(message, privacy: .private)")
        }
    }
}
