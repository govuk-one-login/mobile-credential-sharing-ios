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
///
/// The logging backend is a private implementation detail. Callers describe
/// intent through `Logger.Level` and `Logger.Privacy` and never need to
/// import the underlying logging module, so the backend can be swapped
/// without touching call sites.
public enum Logger {
    /// The severity of a log message, independent of the logging backend.
    public enum Level {
        /// Verbose messages useful during development.
        case debug
        /// Informational messages tracking normal operation.
        case info
        /// Default-level messages.
        case `default`
        /// Errors that are recoverable or expected.
        case error
        /// Serious failures that should not occur in normal operation.
        case fault
    }

    /// Controls how the interpolated message is treated by the logging backend.
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
        level: Level = .debug,
        privacy: Privacy = .public
    ) {
        let osLevel = level.osLogType
        switch privacy {
        case .public:
            logger.log(level: osLevel, "\(message, privacy: .public)")
        case .private:
            logger.log(level: osLevel, "\(message, privacy: .private)")
        }
    }
}

private extension Logger.Level {
    /// Maps the backend-independent level onto the unified logging type.
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .default: return .default
        case .error: return .error
        case .fault: return .fault
        }
    }
}
