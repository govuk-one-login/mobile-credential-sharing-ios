import CryptoKit
import Foundation

/// The certificate material selected from a chain-based COSE_Sign1's headers.
///
/// Produced by ``CertificateHeaderValidator`` once the shared certificate-header profile
/// has been enforced. The candidate leaf is bound to the signed object by a protected
/// `x5t` thumbprint; the full sequence is preserved in the supplied order for path
/// validation, which owns ordering and path checks.

enum CertificateHeaderValidator {
    
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
        if protectedHeader[.x5chainLabel] != nil {
            throw CoseVerificationFailure.malformedCoseSign1
        }

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
}
