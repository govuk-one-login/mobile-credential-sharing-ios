@testable import CoseVerification
import Foundation
import SwiftASN1
import Testing
import X509

/// Unit tests for the tolerant ``KeyUsageValidator`` shared by ``IntermediateKeyUsagePolicy`` and
/// ``EndEntityKeyUsagePolicy``.
///
/// Context: some issued certificates encode their KeyUsage BIT STRING
/// non-canonically — the usage *bits* are correct but the DER padding-bit count does not follow
/// RFC 5280 minimal encoding. swift-certificates' `KeyUsage` initializer is strict and throws
/// `ASN1Error.invalidASN1Object(reason: "Invalid padding bit")` (and the sibling
/// `"Invalid leading padding bit"` / `"Too many bits for Key Usage"`) on such input. The policies
/// wrapped that in `try?`, so a semantically-valid-but-non-canonical certificate was silently
/// rejected.
///
/// These tests use the intermediate requirement (keyCertSign + cRLSign) as the exemplar `required`
/// usage; the matcher is requirement-agnostic, so the end-entity requirement (digitalSignature) is
/// exercised through ``CertificateProfileValidatorTests``. The matcher must:
///   1. accept a canonical, correct encoding;
///   2. accept a non-canonical encoding whose decoded bits equal the requirement;
///   3. reject anything whose decoded bits differ, and reject genuinely malformed input that is not
///      a usable KeyUsage BIT STRING.
@Suite("KeyUsage tolerant matching")
struct KeyUsageValidatorTests {

    /// Exemplar requirement: exactly keyCertSign + cRLSign (the intermediate rule). The matcher is
    /// agnostic to which usage is required.
    private let required = KeyUsage(keyCertSign: true, cRLSign: true)

    /// Wraps raw extnValue DER bytes as a KeyUsage `Certificate.Extension` (OID 2.5.29.15), so a test
    /// can inject exactly the BIT STRING encoding under test — including encodings the typed
    /// `KeyUsage` API refuses to produce.
    private func keyUsageExtension(rawValue: [UInt8], critical: Bool = false) -> Certificate.Extension {
        Certificate.Extension(
            oid: .X509ExtensionID.keyUsage,
            critical: critical,
            value: rawValue[...]
        )
    }

    /// `true` when swift-certificates' *strict* `KeyUsage(_:)` initializer — the path the policy used
    /// before the tolerant matcher — rejects this extension. The case-2 tests assert this is `true`:
    /// if a library update ever started accepting these encodings, the premise of the
    /// fix would be re-examined instead of silently passing.
    private func strictKeyUsageRejects(_ ext: Certificate.Extension) -> Bool {
        (try? KeyUsage(ext)) == nil
    }

    // MARK: - Case 1: valid key usage

    @Test("A canonical keyCertSign+cRLSign BIT STRING matches the requirement")
    func canonicalCorrectKeyUsageMatches() {
        // Canonical DER BIT STRING for bits 5 (keyCertSign) and 6 (cRLSign):
        //   03 02 01 06  →  tag=BIT STRING, len=2, unusedBits=1, data=0b0000_0110.
        // Highest set bit is bit 6, so exactly 1 trailing bit is unused — the minimal encoding.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x01, 0x06])

        // Parity: the strict path accepts the canonical encoding today, and so must the matcher.
        #expect(!strictKeyUsageRejects(ext))
        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("The typed-API encoding of keyCertSign+cRLSign matches the requirement")
    func typedApiEncodingMatches() throws {
        // Belt-and-braces: whatever swift-certificates emits for the typed value must also match, so
        // the primitive stays consistent with the library's own canonical output.
        let ext = try Certificate.Extension(KeyUsage(keyCertSign: true, cRLSign: true), critical: false)

        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    // MARK: - Case 2: badly formatted key

    @Test("A non-canonical BIT STRING (wrong padding count) with correct bits still matches")
    func nonCanonicalPaddingWithCorrectBitsMatches() {
        // Same usage bits (0x06 = keyCertSign + cRLSign) but the unused-bit count is declared as 0
        // instead of the minimal 1:
        //   03 02 00 06  →  unusedBits=0, data=0b0000_0110.
        // swift-certificates rejects this today ("Invalid leading padding bit"): with 0 declared
        // padding bits, the least-significant bit (bit 7) is treated as significant and is 0, which
        // its minimal-encoding check forbids. The decoded usage is nonetheless unambiguously
        // keyCertSign + cRLSign, so the tolerant primitive must accept it.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x00, 0x06])

        // Verified contrast: strict parsing rejects this today; the tolerant matcher must accept it.
        #expect(strictKeyUsageRejects(ext))
        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("A BIT STRING with a trailing zero byte but correct bits still matches")
    func trailingZeroByteWithCorrectBitsMatches() {
        // Another real-world non-canonical form: the correct first byte (0x06) followed by a
        // superfluous trailing zero byte, with a well-formed padding count:
        //   03 03 01 06 00  →  len=3, unusedBits=1, data=0b0000_0110 0b0000_0000.
        // This parses as a valid BIT STRING, but swift-certificates rejects it as "Too many bits for
        // Key Usage" (it allows at most 2 bytes only when paddingBits == 7). The decoded usage is
        // still exactly keyCertSign + cRLSign — the trailing byte sets nothing — so the tolerant
        // primitive must accept it.
        let ext = keyUsageExtension(rawValue: [0x03, 0x03, 0x01, 0x06, 0x00])

        // Verified contrast: strict parsing rejects this today; the tolerant matcher must accept it.
        #expect(strictKeyUsageRejects(ext))
        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    // MARK: - Case 3: completely invalid / wrong format - must always fail

    @Test("A canonical BIT STRING whose bits are not keyCertSign+cRLSign is rejected")
    func wrongUsageBitsRejected() {
        // Canonical and well-formed, but the wrong usage: digitalSignature only (bit 0):
        //   03 02 07 80  →  unusedBits=7, data=0b1000_0000.
        // The encoding parses cleanly; it simply does not equal the required usage, so it must fail
        // regardless of how tolerant the padding handling is.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x07, 0x80])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("A non-canonical BIT STRING whose decoded bits add an extra usage is rejected")
    func extraUsageBitRejected() {
        // digitalSignature + keyCertSign + cRLSign = bits 0, 5, 6, all in the first byte:
        //   0b1000_0110 = 0x86. Encoded non-canonically with 0 declared unused bits:
        //   03 02 00 86.
        // swift-certificates rejects the padding today; the tolerant primitive decodes it to 0x86.
        // Tolerating bad padding must NOT widen the accepted usage set: an intermediate asserting
        // more than keyCertSign + cRLSign (here, the extra digitalSignature bit) must still fail.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x00, 0x86])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("An extension whose value is not a BIT STRING at all is rejected")
    func nonBitStringValueRejected() {
        // The extnValue is a DER INTEGER (tag 0x02), not a BIT STRING (tag 0x03):
        //   02 01 06.
        // This is not a KeyUsage encoding in any form; the primitive must fail closed rather than
        // coerce it into a usage set.
        let ext = keyUsageExtension(rawValue: [0x02, 0x01, 0x06])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("A truncated / structurally invalid BIT STRING is rejected")
    func truncatedBitStringRejected() {
        // BIT STRING tag with a length (2) that overruns the available content:
        //   03 02 01  →  declares 2 content bytes but only the unused-bits byte is present.
        // Undecodable garbage must fail closed.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x01])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("An empty extension value is rejected")
    func emptyValueRejected() {
        let ext = keyUsageExtension(rawValue: [])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }
}

/// Coverage for the end-entity (leaf) requirement — exactly `digitalSignature`. The matcher is
/// requirement-agnostic, so this suite proves the same tolerance and fail-closed behaviour hold when
/// the required usage is the leaf's single `digitalSignature` bit rather than the intermediate's
/// keyCertSign + cRLSign pair. Without it, a regression that only affected the single-bit case (e.g.
/// a wrong mask for bit 0) could slip through.
@Suite("KeyUsage tolerant matching — end-entity (digitalSignature)")
struct KeyUsageValidatorEndEntityTests {

    /// The only permitted end-entity usage: exactly digitalSignature.
    private let required = KeyUsage(digitalSignature: true)

    private func keyUsageExtension(rawValue: [UInt8], critical: Bool = false) -> Certificate.Extension {
        Certificate.Extension(
            oid: .X509ExtensionID.keyUsage,
            critical: critical,
            value: rawValue[...]
        )
    }

    private func strictKeyUsageRejects(_ ext: Certificate.Extension) -> Bool {
        (try? KeyUsage(ext)) == nil
    }

    // MARK: - Case 1: valid key usage

    @Test("A canonical digitalSignature BIT STRING matches the requirement")
    func canonicalCorrectKeyUsageMatches() {
        // Canonical DER BIT STRING for bit 0 (digitalSignature):
        //   03 02 07 80  →  unusedBits=7, data=0b1000_0000.
        // Only bit 0 is set, so the remaining 7 bits of the single byte are unused — minimal.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x07, 0x80])

        // Parity: the strict path accepts the canonical encoding today, and so must the matcher.
        #expect(!strictKeyUsageRejects(ext))
        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("The typed-API encoding of digitalSignature matches the requirement")
    func typedApiEncodingMatches() throws {
        let ext = try Certificate.Extension(KeyUsage(digitalSignature: true), critical: false)

        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    // MARK: - Case 2: badly formatted key

    @Test("A non-canonical digitalSignature BIT STRING (wrong padding count) still matches")
    func nonCanonicalPaddingWithCorrectBitMatches() {
        // Same usage bit (0x80 = digitalSignature) but 0 declared unused bits instead of the minimal 7:
        //   03 02 00 80  →  unusedBits=0, data=0b1000_0000.
        // swift-certificates rejects this today ("Invalid leading padding bit"): with 0 declared
        // padding bits, the least-significant bit is treated as significant and is 0, which its
        // minimal-encoding check forbids. The decoded usage is unambiguously digitalSignature, so the
        // tolerant matcher must accept it. This mirrors the production leaf defect reproduced by
        // `endEntityNonCanonicalKeyUsagePaddingApproved` in CertificateProfileValidatorTests.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x00, 0x80])

        #expect(strictKeyUsageRejects(ext))
        #expect(KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    // MARK: - Case 3: completely invalid / wrong format - must always fail

    @Test("A canonical BIT STRING whose bits are keyCertSign+cRLSign (not digitalSignature) is rejected")
    func wrongUsageBitsRejected() {
        // Canonical keyCertSign + cRLSign (0x06). Correct for an intermediate, but the leaf
        // requirement is digitalSignature, so it must fail here.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x01, 0x06])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("A non-canonical BIT STRING whose decoded bits add an extra usage is rejected")
    func extraUsageBitRejected() {
        // digitalSignature + nonRepudiation = bits 0,1 = 0b1100_0000 = 0xC0, encoded non-canonically
        // with 0 declared unused bits:
        //   03 02 00 C0.
        // Tolerating bad padding must NOT widen the accepted usage: an extra nonRepudiation bit
        // beyond the required digitalSignature must still be rejected.
        let ext = keyUsageExtension(rawValue: [0x03, 0x02, 0x00, 0xC0])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("An extension whose value is not a BIT STRING at all is rejected")
    func nonBitStringValueRejected() {
        let ext = keyUsageExtension(rawValue: [0x02, 0x01, 0x80])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }

    @Test("An empty extension value is rejected")
    func emptyValueRejected() {
        let ext = keyUsageExtension(rawValue: [])

        #expect(!KeyUsageValidator.keyUsageMatches(ext, required: required))
    }
}
