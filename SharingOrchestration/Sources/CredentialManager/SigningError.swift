import Foundation

/// Protocol indicating the user cancelled local authentication (e.g. biometric/passcode prompt).
///
/// When `CredentialProvider.sign()` throws an error conforming to this protocol:
/// - The sharing session remains active.
/// - The user stays on the Agree to Share screen.
/// - No DeviceResponse or termination message is sent to the Verifier.
/// - The user may retry signing, deny sharing, or cancel the journey.
///
/// The Consumer wraps its cancellation error (e.g. `signProofLocalAuthCancelled`)
/// in a type conforming to this protocol before rethrowing from `sign()`.
public protocol LocalAuthCancelled: Error {}

/// Protocol indicating a fatal, unrecoverable signing failure.
///
/// When `CredentialProvider.sign()` throws an error conforming to this protocol:
/// - The SDK transmits an encrypted termination response to the Verifier.
/// - The local session enters a terminal `.failed` state.
/// - The Generic Error screen is displayed to the user.
///
/// The Consumer wraps any non-cancellation signing failure (e.g. `signProofLocalAuthFailed`)
/// in a type conforming to this protocol before rethrowing from `sign()`.
public protocol SignError: Error {}
