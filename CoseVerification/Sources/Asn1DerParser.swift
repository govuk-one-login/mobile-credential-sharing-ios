import Foundation

/// A minimal, strict ASN.1 DER reader for X.509 path validation. Any structural surprise throws
/// `untrustedCertificate` so a malformed certificate is never mistaken for a trusted one.
struct Asn1DerParser {

    enum Tag {
        static let boolean: UInt8 = 0x01
        static let integer: UInt8 = 0x02
        static let bitString: UInt8 = 0x03
        static let octetString: UInt8 = 0x04
        static let objectIdentifier: UInt8 = 0x06
        static let sequence: UInt8 = 0x30 // constructed
        static let utcTime: UInt8 = 0x17
        static let generalizedTime: UInt8 = 0x18
    }

    private let bytes: [UInt8]
    private var offset = 0

    var isAtEnd: Bool { offset >= bytes.count }

    init(_ data: Data) { self.bytes = [UInt8](data) }
    fileprivate init(bytes: [UInt8]) { self.bytes = bytes }

    /// Reads the next TLV element, advancing past it.
    mutating func readElement() throws -> Element {
        let start = offset
        guard offset < bytes.count else { throw CoseVerificationFailure.untrustedCertificate }
        let tag = bytes[offset]
        offset += 1
        let length = try readLength()
        guard length <= bytes.count - offset else { throw CoseVerificationFailure.untrustedCertificate }
        let content = Data(bytes[offset ..< offset + length])
        offset += length
        return Element(tag: tag, content: content, encoded: Data(bytes[start ..< offset]))
    }

    /// Reads a definite-form DER length. Indefinite and oversized forms are rejected.
    private mutating func readLength() throws -> Int {
        guard offset < bytes.count else { throw CoseVerificationFailure.untrustedCertificate }
        let first = bytes[offset]
        offset += 1
        if first & 0x80 == 0 { return Int(first) } // short form
        let count = Int(first & 0x7F) // long form: number of length octets
        guard count > 0, count <= 8, offset + count <= bytes.count else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        var length = 0
        for _ in 0 ..< count { length = (length << 8) | Int(bytes[offset]); offset += 1 }
        guard length >= 0 else { throw CoseVerificationFailure.untrustedCertificate }
        return length
    }
}

// MARK: - Element

extension Asn1DerParser {

    /// A parsed TLV element: tag, content octets, and the full tag-length-value bytes (so callers
    /// can compare or hash exact DER, e.g. Names and the `tbsCertificate`).
    struct Element {
        let tag: UInt8
        let content: Data
        let encoded: Data

        var contextTagNumber: UInt8 { tag & 0x1F }
        var isContextSpecific: Bool { (tag & 0xC0) == 0x80 }
        func isContext(_ number: UInt8) -> Bool { isContextSpecific && contextTagNumber == number }

        /// Asserts this element's tag, else throws `untrustedCertificate`.
        func require(_ expected: UInt8) throws {
            guard tag == expected else { throw CoseVerificationFailure.untrustedCertificate }
        }

        /// A parser over this element's content.
        func parseContent() -> Asn1DerParser { Asn1DerParser(bytes: [UInt8](content)) }

        /// Requires SEQUENCE and returns a parser over its content.
        func sequenceContent() throws -> Asn1DerParser {
            try require(Tag.sequence)
            return parseContent()
        }

        /// Decodes an OBJECT IDENTIFIER into dotted-decimal form.
        func objectIdentifier() throws -> String {
            try require(Tag.objectIdentifier)
            guard let first = content.first else { throw CoseVerificationFailure.untrustedCertificate }
            var components = [Int(first) / 40, Int(first) % 40] // first octet: 40*X + Y
            var value = 0
            for octet in content.dropFirst() {
                value = (value << 7) | Int(octet & 0x7F)
                if octet & 0x80 == 0 { components.append(value); value = 0 }
            }
            return components.map(String.init).joined(separator: ".")
        }

        /// BIT STRING content with the leading "unused bits" octet stripped. The unused-bits count
        /// must be 0 for the DER-encoded keys and identifiers handled here; anything else is malformed.
        func bitStringBytes() throws -> Data {
            try require(Tag.bitString)
            guard let unusedBits = content.first, unusedBits == 0 else {
                throw CoseVerificationFailure.untrustedCertificate
            }
            return content.dropFirst()
        }

        /// Raw OCTET STRING content.
        func octetStringBytes() throws -> Data {
            try require(Tag.octetString)
            return content
        }

        /// Parses a UTCTime or GeneralizedTime element into a `Date` (see ``Asn1Time``).
        func time() throws -> Date {
            switch tag {
            case Tag.utcTime:
                return try Asn1Time.date(from: content, isUTCTime: true)
            case Tag.generalizedTime:
                return try Asn1Time.date(from: content, isUTCTime: false)
            default:
                throw CoseVerificationFailure.untrustedCertificate
            }
        }
    }
}
