@testable import CoseVerification
import Foundation
import Testing

@Suite("ASN.1 DER parsing")
struct Asn1DerParserTests {

    private func data(_ bytes: [UInt8]) -> Data { Data(bytes) }

    // MARK: - readElement: tag, length, value split

    @Test("A short-form TLV is split into tag, content, and full encoding")
    func shortFormElement() throws {
        // INTEGER (0x02), length 1, value 0x2A
        var parser = Asn1DerParser(data([0x02, 0x01, 0x2A]))
        let element = try parser.readElement()

        #expect(element.tag == Asn1DerParser.Tag.integer)
        #expect(element.content == data([0x2A]))
        #expect(element.encoded == data([0x02, 0x01, 0x2A]))
        #expect(parser.isAtEnd)
    }

    @Test("An empty-content element reads with a zero-length body")
    func zeroLengthElement() throws {
        // NULL-like: tag 0x05, length 0
        var parser = Asn1DerParser(data([0x05, 0x00]))
        let element = try parser.readElement()

        #expect(element.content.isEmpty)
        #expect(element.encoded == data([0x05, 0x00]))
        #expect(parser.isAtEnd)
    }

    @Test("Sequential elements are read in order, advancing the offset")
    func sequentialElements() throws {
        // INTEGER 1, then BOOLEAN true
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01, 0x01, 0x01, 0xFF]))

        let first = try parser.readElement()
        #expect(first.tag == Asn1DerParser.Tag.integer)
        #expect(first.content == data([0x01]))
        #expect(!parser.isAtEnd)

        let second = try parser.readElement()
        #expect(second.tag == Asn1DerParser.Tag.boolean)
        #expect(second.content == data([0xFF]))
        #expect(parser.isAtEnd)
    }

    @Test("Reading past the end of the buffer is rejected")
    func readPastEnd() {
        var parser = Asn1DerParser(data([]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    @Test("A tag with no following length octet is rejected")
    func missingLengthOctet() {
        var parser = Asn1DerParser(data([0x02]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    @Test("A declared length exceeding the remaining bytes is rejected")
    func lengthExceedsRemaining() {
        // INTEGER, claims 5 content bytes but only 2 are present
        var parser = Asn1DerParser(data([0x02, 0x05, 0x00, 0x01]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    // MARK: - readLength: long form

    @Test("A long-form length octet is decoded")
    func longFormLength() throws {
        // OCTET STRING, long form 0x81 => 1 length octet => 0x02, then 2 content bytes
        var parser = Asn1DerParser(data([0x04, 0x81, 0x02, 0xAB, 0xCD]))
        let element = try parser.readElement()

        #expect(element.tag == Asn1DerParser.Tag.octetString)
        #expect(element.content == data([0xAB, 0xCD]))
    }

    @Test("A two-octet long-form length is decoded")
    func longFormTwoOctetLength() throws {
        // OCTET STRING, 0x82 => 2 length octets => 0x0001 => 1 content byte
        var parser = Asn1DerParser(data([0x04, 0x82, 0x00, 0x01, 0x7F]))
        let element = try parser.readElement()

        #expect(element.content == data([0x7F]))
    }

    @Test("A long form claiming zero length octets is rejected")
    func longFormZeroCount() {
        // 0x80 is the indefinite-form indicator: count == 0, which DER forbids
        var parser = Asn1DerParser(data([0x04, 0x80]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    @Test("A long form declaring more than 8 length octets is rejected")
    func longFormOversizedCount() {
        // 0x89 => 9 length octets, above the 8-octet cap
        var parser = Asn1DerParser(data([0x04, 0x89, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    @Test("A long form with truncated length octets is rejected")
    func longFormTruncatedLength() {
        // 0x82 promises 2 length octets but only 1 follows
        var parser = Asn1DerParser(data([0x04, 0x82, 0x00]))
        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try parser.readElement()
        }
    }

    // MARK: - Element.require / tag helpers

    @Test("require passes for a matching tag and throws for a mismatch")
    func requireTag() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x05]))
        let element = try parser.readElement()

        try element.require(Asn1DerParser.Tag.integer) // no throw

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            try element.require(Asn1DerParser.Tag.sequence)
        }
    }

    @Test("Context-specific tag detection reports class and number")
    func contextSpecificTag() throws {
        // [0] context-specific constructed tag 0xA0, length 0
        var parser = Asn1DerParser(data([0xA0, 0x00]))
        let element = try parser.readElement()

        #expect(element.isContextSpecific)
        #expect(element.contextTagNumber == 0)
        #expect(element.isContext(0))
        #expect(!element.isContext(3))
    }

    @Test("A universal tag is not reported as context-specific")
    func universalTagNotContextSpecific() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01]))
        let element = try parser.readElement()

        #expect(!element.isContextSpecific)
        #expect(!element.isContext(0))
    }

    // MARK: - Element.sequenceContent

    @Test("sequenceContent returns a parser over a SEQUENCE body")
    func sequenceContent() throws {
        // SEQUENCE { INTEGER 1 }: 30 03 02 01 01
        var outer = Asn1DerParser(data([0x30, 0x03, 0x02, 0x01, 0x01]))
        let seq = try outer.readElement()

        var inner = try seq.sequenceContent()
        let integer = try inner.readElement()
        #expect(integer.tag == Asn1DerParser.Tag.integer)
        #expect(integer.content == data([0x01]))
        #expect(inner.isAtEnd)
    }

    @Test("sequenceContent rejects a non-SEQUENCE element")
    func sequenceContentWrongTag() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.sequenceContent()
        }
    }

    // MARK: - Element.objectIdentifier

    @Test("An OBJECT IDENTIFIER decodes to dotted-decimal form")
    func objectIdentifier() throws {
        // OID 1.2.840.10045.4.3.2 (ecdsa-with-SHA256): 06 08 2A 86 48 CE 3D 04 03 02
        var parser = Asn1DerParser(data([0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x04, 0x03, 0x02]))
        let element = try parser.readElement()

        #expect(try element.objectIdentifier() == "1.2.840.10045.4.3.2")
    }

    @Test("The first OID octet encodes the 40*X + Y arc pair")
    func objectIdentifierFirstArc() throws {
        // OID 2.5.29.15 (keyUsage): 06 03 55 1D 0F  (0x55 = 85 = 40*2 + 5)
        var parser = Asn1DerParser(data([0x06, 0x03, 0x55, 0x1D, 0x0F]))
        let element = try parser.readElement()

        #expect(try element.objectIdentifier() == "2.5.29.15")
    }

    @Test("An empty OBJECT IDENTIFIER body is rejected")
    func objectIdentifierEmpty() throws {
        var parser = Asn1DerParser(data([0x06, 0x00]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.objectIdentifier()
        }
    }

    @Test("objectIdentifier rejects a non-OID tag")
    func objectIdentifierWrongTag() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.objectIdentifier()
        }
    }

    // MARK: - Element.bitStringBytes

    @Test("A BIT STRING with zero unused bits strips the leading count octet")
    func bitStringZeroUnused() throws {
        // BIT STRING: 03 04 00 AB CD EF  (00 unused bits, payload AB CD EF)
        var parser = Asn1DerParser(data([0x03, 0x04, 0x00, 0xAB, 0xCD, 0xEF]))
        let element = try parser.readElement()

        #expect(try element.bitStringBytes() == data([0xAB, 0xCD, 0xEF]))
    }

    @Test("A BIT STRING with non-zero unused bits is rejected")
    func bitStringNonZeroUnused() throws {
        // 04 unused bits is not permitted for the keys/identifiers handled here
        var parser = Asn1DerParser(data([0x03, 0x02, 0x04, 0xF0]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.bitStringBytes()
        }
    }

    @Test("An empty BIT STRING body is rejected")
    func bitStringEmpty() throws {
        var parser = Asn1DerParser(data([0x03, 0x00]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.bitStringBytes()
        }
    }

    @Test("bitStringBytes rejects a non-BIT-STRING tag")
    func bitStringWrongTag() throws {
        var parser = Asn1DerParser(data([0x04, 0x01, 0x00]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.bitStringBytes()
        }
    }

    // MARK: - Element.octetStringBytes

    @Test("An OCTET STRING returns its raw content")
    func octetStringBytes() throws {
        var parser = Asn1DerParser(data([0x04, 0x03, 0x01, 0x02, 0x03]))
        let element = try parser.readElement()

        #expect(try element.octetStringBytes() == data([0x01, 0x02, 0x03]))
    }

    @Test("octetStringBytes rejects a non-OCTET-STRING tag")
    func octetStringWrongTag() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.octetStringBytes()
        }
    }

    // MARK: - Element.time (delegation to Asn1Time)

    @Test("A UTCTime element parses via Asn1Time")
    func utcTimeElement() throws {
        // UTCTime "260907163526Z": tag 0x17, length 13
        let body: [UInt8] = Array("260907163526Z".utf8)
        var parser = Asn1DerParser(data([0x17, UInt8(body.count)] + body))
        let element = try parser.readElement()

        let date = try element.time()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(calendar.component(.year, from: date) == 2026)
    }

    @Test("A GeneralizedTime element parses via Asn1Time")
    func generalizedTimeElement() throws {
        // GeneralizedTime "20991231235959Z": tag 0x18, length 15
        let body: [UInt8] = Array("20991231235959Z".utf8)
        var parser = Asn1DerParser(data([0x18, UInt8(body.count)] + body))
        let element = try parser.readElement()

        let date = try element.time()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        #expect(calendar.component(.year, from: date) == 2099)
    }

    @Test("time rejects a tag that is neither UTCTime nor GeneralizedTime")
    func timeWrongTag() throws {
        var parser = Asn1DerParser(data([0x02, 0x01, 0x01]))
        let element = try parser.readElement()

        #expect(throws: CoseVerificationFailure.untrustedCertificate) {
            _ = try element.time()
        }
    }
}
