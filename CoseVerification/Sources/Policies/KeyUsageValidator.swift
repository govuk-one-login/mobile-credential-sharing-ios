import SwiftASN1
import X509

/// Tolerant matcher for an X.509 KeyUsage extension, shared by the intermediate and end-entity
/// KeyUsage profile policies.
///
/// **Why this exists — AWS Private CA bug.** KeyUsage has 9 possible bits (0–8), and RFC 5280
/// requires the DER BIT STRING to omit trailing zero bits (minimal encoding). For keyCertSign +
/// cRLSign the correct encoding is therefore the 7 significant bits `0000011`. AWS Private CA
/// (ACM PCA) instead emits all 9 bits, `000001100` — semantically identical (it means the same
/// usages) but syntactically wrong per RFC 5280, and it does so whenever it is asked to encode
/// KeyUsage. swift-certificates' `KeyUsage(_ ext:)` initializer is strict about minimal encoding and
/// rejects the AWS form, throwing `ASN1Error.invalidASN1Object(reason: "Invalid padding bit")` (or
/// the sibling `"Invalid leading padding bit"` / `"Too many bits for Key Usage"`). Because our CA
/// chain is issued by AWS Private CA, this rejected otherwise-valid intermediate and end-entity
/// certificates in production.
///
/// Per the AWS Private CA documentation: "By default, AWS Private CA generates nine-bit KeyUsage
/// extension values, with the ninth bit resulting in an extra byte."
/// <https://docs.aws.amazon.com/privateca/latest/userguide/TroubleshootPcaMatter.html>
///
/// This matcher decodes the BIT STRING *structurally* (any valid DER BIT STRING, regardless of
/// minimal-encoding rules), interprets the usage bits itself, and compares them to the requirement.
/// It deliberately does **not** relax semantics: the decoded usage must equal `required` exactly, so
/// a certificate asserting the wrong or additional usages is still rejected. Input that is not a
/// usable BIT STRING (wrong tag, truncated, too many bytes) fails closed.
///
/// The caller supplies the required usage, so the same matcher serves both the intermediate
/// requirement (keyCertSign + cRLSign) and the end-entity requirement (digitalSignature).
enum KeyUsageValidator {

    /// Returns `true` when `ext` decodes to a KeyUsage whose set of usage bits is exactly `required`,
    /// tolerating non-minimal BIT STRING padding. Returns `false` for any mismatch or for input that
    /// is not a decodable KeyUsage BIT STRING.
    static func keyUsageMatches(_ ext: Certificate.Extension, required: KeyUsage) -> Bool {
        guard ext.oid == .X509ExtensionID.keyUsage else { return false }
        guard let decoded = decode(ext.value) else { return false }
        return decoded == required
    }

    /// Structurally decodes a KeyUsage extension value (a DER BIT STRING) into a ``KeyUsage``,
    /// ignoring minimal-encoding/padding strictness. Returns `nil` if the value is not a BIT STRING
    /// or carries more bits than KeyUsage can represent.
    static func decode(_ value: ArraySlice<UInt8>) -> KeyUsage? {
        // Parse the BIT STRING structure. This accepts non-minimal padding (which `KeyUsage(_:)`
        // rejects) but still rejects a non-BIT-STRING tag, a truncated/over-long structure, or an
        // out-of-range padding-bit count.
        guard let bitString = try? ASN1BitString(derEncoded: Array(value)) else { return nil }

        // KeyUsage is at most 9 bits → at most 2 content bytes. Reject anything wider.
        let bytes = Array(bitString.bytes)
        guard bytes.count <= 2 else { return nil }

        // Reconstruct the 9-bit usage field. Byte 0 holds usage bits 0–7 (MSB-first); byte 1, when
        // present, holds bit 8 (decipherOnly) in its top bit. This mirrors swift-certificates' own
        // byte→rawValue mapping, so the resulting `KeyUsage` compares equal to a canonically decoded
        // one with the same bits.
        let byte0 = bytes.count >= 1 ? bytes[0] : 0
        let byte1 = bytes.count >= 2 ? bytes[1] : 0

        return KeyUsage(
            digitalSignature: byte0 & Bit.digitalSignature != 0,
            nonRepudiation: byte0 & Bit.nonRepudiation != 0,
            keyEncipherment: byte0 & Bit.keyEncipherment != 0,
            dataEncipherment: byte0 & Bit.dataEncipherment != 0,
            keyAgreement: byte0 & Bit.keyAgreement != 0,
            keyCertSign: byte0 & Bit.keyCertSign != 0,
            cRLSign: byte0 & Bit.cRLSign != 0,
            encipherOnly: byte0 & Bit.encipherOnly != 0,
            decipherOnly: byte1 & Bit.decipherOnly != 0
        )
    }
}

// MARK: - Bit extension with KeyUsage usages

extension KeyUsageValidator {
    /// DER BIT STRING masks for the KeyUsage usages (RFC 5280 §4.2.1.3). Usage bits are numbered
    /// MSB-first: bit 0 is the top bit of the first byte. Bits 0–7 live in the first content byte;
    /// bit 8 (`decipherOnly`) lives in the top bit of the second byte. Each mask isolates one bit so
    /// `byte & Bit.x != 0` reads as "is usage x asserted?".
    private enum Bit {
        // First byte: usage bits 0–7.
        static let digitalSignature: UInt8 = 0x80 // bit 0
        static let nonRepudiation: UInt8 = 0x40   // bit 1
        static let keyEncipherment: UInt8 = 0x20  // bit 2
        static let dataEncipherment: UInt8 = 0x10 // bit 3
        static let keyAgreement: UInt8 = 0x08     // bit 4
        static let keyCertSign: UInt8 = 0x04      // bit 5
        static let cRLSign: UInt8 = 0x02          // bit 6
        static let encipherOnly: UInt8 = 0x01     // bit 7
        // Second byte: usage bit 8 in its top bit.
        static let decipherOnly: UInt8 = 0x80     // bit 8
    }
}

extension Certificate.Extensions {
    /// The KeyUsage extension decoded tolerantly, mirroring the library's ``keyUsage`` accessor but
    /// accepting non-canonical BIT STRING padding (see ``KeyUsageValidator``). Returns `nil` when the
    /// extension is absent or cannot be decoded as a KeyUsage BIT STRING — so, unlike ``keyUsage``,
    /// it never throws and fails closed.
    ///
    /// Lets the profile policies read `extensions.tolerantKeyUsage == required` just as they would
    /// with the strict `try? extensions.keyUsage`, while tolerating the padding defect seen in some
    /// issued certificates.
    var tolerantKeyUsage: KeyUsage? {
        self[oid: .X509ExtensionID.keyUsage].flatMap { KeyUsageValidator.decode($0.value) }
    }
}
