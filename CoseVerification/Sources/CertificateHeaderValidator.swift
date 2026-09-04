import CryptoKit
import Foundation

/// Certificate material selected from a chain-based COSE_Sign1's headers.
///
/// Produced by ``CertificateHeaderValidator``. The candidate leaf is bound to the signed
/// object by the protected `x5t`; the chain is preserved in supplied order for C5 path
/// validation.
struct CertificateHeaderMaterial: Sendable, Equatable {
    /// The first `x5chain` certificate (DER), selected as the candidate signing leaf.
    let candidateLeaf: Data

    /// The full `x5chain` sequence in supplied leaf-first order, preserved unchanged.
    let certificateChain: [Data]
}

/// Enforces the shared certificate-header profile for IssuerAuth and ReaderAuth

/// The profile is identical for both trust paths:
/// - `x5bag` (32): ignored in either header; never chain material or an `x5chain` fallback.
/// - `x5chain` (33): required in the unprotected header as one DER byte string or a non-empty
///   array of DER byte strings; rejected in the protected header. First certificate is the
///   candidate leaf; supplied order is preserved.
/// - `x5t` (34): required in the protected header as `[SHA-256 (-16), hashValue]`, where
///   `hashValue` is the 32-byte SHA-256 digest of the first `x5chain` certificate; rejected
///   in the unprotected header.

/// It does not validate certificate order, build or repair the path, or enforce the X.509
/// profile.
enum CertificateHeaderValidator {

    /// COSE algorithm identifier for SHA-256, used in an `x5t` thumbprint (RFC 9360).
    private static let sha256HashAlgorithm: Int64 = -16

    /// Length in bytes of a SHA-256 digest.
    private static let sha256DigestLength = 32

    /// Enforces the certificate-header profile on a decoded chain-based COSE_Sign1.

    /// - Parameter coseSign1: The structurally validated COSE_Sign1 (from ``CoseSign1Decoder``).
    /// - Returns: The candidate leaf and preserved certificate sequence for path validation.
    /// - Throws: ``CoseVerificationFailure`` when the headers violate the profile above.
    static func validate(_ coseSign1: CoseSign1) throws -> CertificateHeaderMaterial {
        // Step 2: extract x5chain and select the candidate leaf. x5bag is never consulted.
        let certificateChain = try extractChain(
            protectedHeader: coseSign1.protectedHeader,
            unprotectedHeader: coseSign1.unprotectedHeader
        )
        let candidateLeaf = certificateChain[0]

        // Step 3: verify the protected x5t binds the candidate leaf.
        try validateThumbprint(
            protectedHeader: coseSign1.protectedHeader,
            unprotectedHeader: coseSign1.unprotectedHeader,
            candidateLeaf: candidateLeaf
        )

        return CertificateHeaderMaterial(
            candidateLeaf: candidateLeaf,
            certificateChain: certificateChain
        )
    }

    // MARK: - x5chain (label 33)

    /// Extracts the `x5chain` sequence, enforcing presence, placement, and shape.
    /// Required in the unprotected header (rejected in the protected header) as one DER byte
    /// string or a non-empty array of DER byte strings.
    private static func extractChain(
        protectedHeader: CoseHeaderMap,
        unprotectedHeader: CoseHeaderMap
    ) throws -> [Data] {
        // Prohibited placement.
        if protectedHeader[.x5chainLabel] != nil {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Absent from both headers. x5bag is never a fallback.
        guard let chainValue = unprotectedHeader[.x5chainLabel] else {
            throw CoseVerificationFailure.missingX5Chain
        }

        switch chainValue {
        case .bytes(let der):
            // Single certificate: a one-element chain.
            return [der]

        case .array(let elements):
            // Non-empty array of certificate byte strings, in supplied order.
            guard !elements.isEmpty else {
                throw CoseVerificationFailure.malformedCoseSign1
            }
            var chain: [Data] = []
            chain.reserveCapacity(elements.count)
            for element in elements {
                guard case .bytes(let der) = element else {
                    throw CoseVerificationFailure.malformedCoseSign1
                }
                chain.append(der)
            }
            return chain

        default:
            // Neither a DER byte string nor a non-empty DER array.
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }

    // MARK: - x5t (label 34)

    /// Validates the protected `x5t` thumbprint against the candidate leaf.
    /// Required in the protected header (rejected in the unprotected header) as
    /// `[SHA-256 (-16), hashValue]`, where `hashValue` is the 32-byte SHA-256 digest of the leaf.
    private static func validateThumbprint(
        protectedHeader: CoseHeaderMap,
        unprotectedHeader: CoseHeaderMap,
        candidateLeaf: Data
    ) throws {
        // Prohibited placement.
        if unprotectedHeader[.x5tLabel] != nil {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Missing from the protected header.
        guard let thumbprintValue = protectedHeader[.x5tLabel] else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Must be [hashAlgorithm, hashValue].
        guard case .array(let elements) = thumbprintValue, elements.count == 2 else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let hashAlgorithm = try coseAlgorithmIdentifier(from: elements[0])

        guard case .bytes(let hashValue) = elements[1] else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Algorithm policy is checked once the shape is established.
        guard hashAlgorithm == sha256HashAlgorithm else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        // A SHA-256 digest is exactly 32 bytes.
        guard hashValue.count == sha256DigestLength else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Mismatch is an integrity failure, not a path failure.
        let expectedDigest = Data(SHA256.hash(data: candidateLeaf))
        guard hashValue == expectedDigest else {
            throw CoseVerificationFailure.invalidSignature
        }
    }

    /// Reads a COSE algorithm identifier (an integer) from an `x5t` first element.
    private static func coseAlgorithmIdentifier(from value: CborValue) throws -> Int64 {
        switch value {
        case .int(let identifier):
            return identifier
        case .uint(let identifier):
            return Int64(identifier)
        default:
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }
}
