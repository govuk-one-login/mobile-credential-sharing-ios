import CryptoKit
import Foundation

/// The certificate material selected from a chain-based COSE_Sign1's headers.
///
/// Produced by ``CertificateHeaderValidator`` once the shared certificate-header profile
/// has been enforced. The candidate leaf is bound to the signed object by a protected
/// `x5t` thumbprint; the full sequence is preserved in the supplied order for path
/// validation, which owns ordering and path checks.

enum CertificateHeaderValidator {
    
    /// The COSE algorithm identifier for SHA-256 used in an `x5t` thumbprint (RFC 9360).
    private static let sha256HashAlgorithm: Int64 = -16

    /// The required length, in bytes, of a SHA-256 digest.
    private static let sha256DigestLength = 32
    
    static func validate(_ coseSign1: CoseSign1) throws {
    }

    // MARK: - x5chain (label 33)

    /// Extracts the `x5chain` certificate sequence, enforcing presence, placement, and shape.
    ///
    /// - Presence/placement: required in the unprotected header, prohibited in the protected header.
    /// - Shape: one DER certificate byte string, or a non-empty array of DER certificate byte strings.
    private static func extractChain(
        protectedHeader: CoseHeaderMap,
        unprotectedHeader: CoseHeaderMap
    ) throws -> [Data] {
        // x5chain in the protected header is prohibited placement → MalformedCoseSign1.
        if protectedHeader[.x5chainLabel] != nil {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // x5chain absent from both headers → MissingX5Chain.
        // (x5bag is never a fallback: an unprotected value here is only ever x5chain.)
        guard let chainValue = unprotectedHeader[.x5chainLabel] else {
            throw CoseVerificationFailure.missingX5Chain
        }

        switch chainValue {
        case .bytes(let der):
            // One certificate byte string: a single-element leaf-first chain.
            return [der]

        case .array(let elements):
            // A non-empty array of certificate byte strings, in the supplied order.
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
            // Neither a single DER byte string nor a non-empty DER array.
            throw CoseVerificationFailure.malformedCoseSign1
        }
    }

    // MARK: - x5t (label 34)

    /// Validates the protected `x5t` thumbprint against the candidate leaf.
    /// - Presence/placement: required in the protected header, prohibited in the unprotected header.
    /// - Shape: an array of exactly two elements `[hashAlgorithm, hashValue]`.
    /// - Algorithm: `hashAlgorithm` must be SHA-256 (-16).
    /// - Value: `hashValue` must be a 32-byte byte string equal to the SHA-256 digest of the leaf.
    private static func validateThumbprint(
        protectedHeader: CoseHeaderMap,
        unprotectedHeader: CoseHeaderMap,
        candidateLeaf: Data
    ) throws {
        // x5t in the unprotected header is prohibited placement → MalformedCoseSign1.
        if unprotectedHeader[.x5tLabel] != nil {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // x5t missing from the protected header → MalformedCoseSign1.
        guard let thumbprintValue = protectedHeader[.x5tLabel] else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // x5t must be an array of exactly two elements: [hashAlgorithm, hashValue].
        guard case .array(let elements) = thumbprintValue, elements.count == 2 else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let hashAlgorithm = try coseAlgorithmIdentifier(from: elements[0])

        // The second element must be a byte string.
        guard case .bytes(let hashValue) = elements[1] else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        // Once the shape is established, an algorithm other than SHA-256 is unsupported.
        guard hashAlgorithm == sha256HashAlgorithm else {
            throw CoseVerificationFailure.unsupportedAlgorithm
        }

        // A SHA-256 digest is exactly 32 bytes; any other length is malformed.
        guard hashValue.count == sha256DigestLength else {
            throw CoseVerificationFailure.malformedCoseSign1
        }

        let expectedDigest = Data(SHA256.hash(data: candidateLeaf))
        guard hashValue == expectedDigest else {
            throw CoseVerificationFailure.invalidSignature
        }
    }

    /// Reads a COSE algorithm identifier from an `x5t` first element.
    /// A COSE algorithm identifier is an integer; anything else is a malformed thumbprint.
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
