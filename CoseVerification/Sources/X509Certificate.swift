import Foundation

/// A minimal DER decode of an X.509 certificate, exposing only the fields the allow-list checks in
/// ``CertificatePathValidator`` need: the signature algorithms, validity window, public-key
/// algorithm/curve, and extensions. It enforces strict DER framing (one Certificate, no trailing
/// bytes) but no policy. Other elements (signatureValue, issuer, subject, key bits) are read only
/// to advance the parser — `SecTrust` handles all linkage and signature checks.
///
/// This decode exists because iOS does not expose parsed certificate fields
/// (`SecCertificateCopyValues` is macOS-only).
///
/// ```
/// Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue BIT STRING }
/// TBSCertificate ::= SEQUENCE {
///   [0] version, serialNumber, signature, issuer, validity, subject,
///   subjectPublicKeyInfo, ... [3] extensions }
/// ```
struct X509Certificate {

    /// A single extension: OID, criticality, and raw value octets.
    struct Extension {
        let oid: String
        let critical: Bool
        let value: Data
    }

    let notBefore: Date
    let notAfter: Date
    let signatureAlgorithmOid: String    // outer Certificate.signatureAlgorithm
    let tbsSignatureAlgorithmOid: String // tbsCertificate.signature
    let subjectPublicKeyAlgorithmOid: String
    let subjectPublicKeyCurveOid: String?
    let extensions: [Extension]

    /// Parses a DER certificate. Any structural problem throws `untrustedCertificate`.
    init(der: Data) throws {
        var top = Asn1DerParser(der)
        let certificate = try top.readElement()
        // Exactly one Certificate, no trailing bytes.
        guard top.isAtEnd else { throw CoseVerificationFailure.untrustedCertificate }
        var certBody = try certificate.sequenceContent()

        let tbs = try certBody.readElement()
        self.signatureAlgorithmOid = try Self.algorithmOid(certBody.readElement())
        _ = try certBody.readElement().bitStringBytes() // signatureValue (verified by SecTrust)

        var tbsBody = try tbs.sequenceContent()
        var field = try tbsBody.readElement()
        if field.isContext(0) { field = try tbsBody.readElement() } // optional [0] version
        try field.require(Asn1DerParser.Tag.integer) // serialNumber (unused)

        self.tbsSignatureAlgorithmOid = try Self.algorithmOid(tbsBody.readElement())
        _ = try tbsBody.readElement().encoded // issuer (linkage handled by SecTrust)
        (self.notBefore, self.notAfter) = try Self.validity(tbsBody.readElement())
        _ = try tbsBody.readElement().encoded // subject (linkage handled by SecTrust)
        (subjectPublicKeyAlgorithmOid, subjectPublicKeyCurveOid) =
            try Self.subjectPublicKeyInfo(tbsBody.readElement())

        // Only [3] extensions are needed.
        var parsed: [Extension] = []
        while !tbsBody.isAtEnd {
            let element = try tbsBody.readElement()
            if element.isContext(3) { parsed = try Self.extensions(element) }
        }
        self.extensions = parsed
    }

    // MARK: - Field parsers

    /// Reads the OID from `AlgorithmIdentifier ::= SEQUENCE { algorithm OID, parameters ANY }`.
    private static func algorithmOid(_ element: Asn1DerParser.Element) throws -> String {
        var body = try element.sequenceContent()
        return try body.readElement().objectIdentifier()
    }

    /// Reads `Validity ::= SEQUENCE { notBefore Time, notAfter Time }`.
    private static func validity(_ element: Asn1DerParser.Element) throws -> (Date, Date) {
        var body = try element.sequenceContent()
        return (try body.readElement().time(), try body.readElement().time())
    }

    /// Reads `SubjectPublicKeyInfo`, returning (algorithm OID, named-curve OID?).
    private static func subjectPublicKeyInfo(
        _ element: Asn1DerParser.Element
    ) throws -> (String, String?) {
        var body = try element.sequenceContent()
        var algBody = try body.readElement().sequenceContent()
        _ = try body.readElement().bitStringBytes() // key bits (used by SecTrust for signatures)

        let algOid = try algBody.readElement().objectIdentifier()
        var curveOid: String?
        if !algBody.isAtEnd {
            let parameters = try algBody.readElement()
            if parameters.tag == Asn1DerParser.Tag.objectIdentifier {
                curveOid = try parameters.objectIdentifier()
            }
        }
        return (algOid, curveOid)
    }

    /// Reads `Extensions` from the `[3] EXPLICIT` wrapper.
    /// `Extension ::= SEQUENCE { extnID OID, critical BOOLEAN DEFAULT FALSE, extnValue OCTET STRING }`.
    private static func extensions(_ wrapper: Asn1DerParser.Element) throws -> [Extension] {
        var explicitBody = wrapper.parseContent()
        var seqBody = try explicitBody.readElement().sequenceContent()

        var result: [Extension] = []
        while !seqBody.isAtEnd {
            var extBody = try seqBody.readElement().sequenceContent()
            let oid = try extBody.readElement().objectIdentifier()

            var critical = false
            var next = try extBody.readElement()
            if next.tag == Asn1DerParser.Tag.boolean {
                // DER BOOLEAN is a single octet: 0xFF = TRUE, 0x00 = FALSE. Reject any other value
                // rather than treating a non-canonical byte as FALSE.
                guard next.content.count == 1 else { throw CoseVerificationFailure.untrustedCertificate }
                switch next.content[next.content.startIndex] {
                case 0xFF: critical = true
                case 0x00: critical = false
                default: throw CoseVerificationFailure.untrustedCertificate
                }
                next = try extBody.readElement()
            }
            result.append(Extension(oid: oid, critical: critical, value: try next.octetStringBytes()))
        }
        return result
    }
}
