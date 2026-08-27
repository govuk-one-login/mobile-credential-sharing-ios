import Foundation

/// The payload mode expected by the caller for a COSE_Sign1 verification operation.
enum PayloadMode: Sendable {
    /// The payload is embedded in the COSE_Sign1 structure (e.g. IssuerAuth).
    case attached

    /// The payload is supplied externally by the caller (e.g. DeviceAuth, ReaderAuth).
    case detached(externalPayload: Data)
}

/// Validates that a decoded COSE_Sign1 structure matches the expected payload mode.
///
/// - **Attached mode:** The COSE_Sign1 must contain a non-nil payload.
///   A null payload (detached structure) is rejected as `malformedCoseSign1`.
///
/// - **Detached mode:** The COSE_Sign1 must contain a nil payload.
///   A non-nil payload (attached structure) is rejected as `malformedCoseSign1`.
///
/// This type is internal to the `CoseVerification` module.
enum PayloadModeValidator {

    /// Validates the payload mode and returns the effective payload bytes
    /// for downstream `Sig_structure` construction.
    ///
    /// - Parameters:
    ///   - decoded: The structurally validated `CoseSign1`.
    ///   - mode: The expected payload mode for this verification operation.
    /// - Returns: The payload bytes to use in signature verification.
    /// - Throws: `CoseVerificationFailure.malformedCoseSign1` if the payload presence
    ///   does not match the expected mode.
    static func payload(for mode: PayloadMode, from decoded: CoseSign1) throws -> Data {
        switch mode {
        case .attached:
            guard let payload = decoded.payload else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            return payload

        case .detached(let externalPayload):
            guard decoded.payload == nil else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            return externalPayload
        }
    }
}
