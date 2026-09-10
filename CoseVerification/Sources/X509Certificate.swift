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

    /// The `TBSCertificate` fields the allow-lists need, gathered in one decode pass.
    private struct TBSFields {
        let signatureAlgorithmOid: String
        let notBefore: Date
        let notAfter: Date
        let publicKeyAlgorithmOid: String
        let publicKeyCurveOid: String?
        let extensions: [Extension]
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

        // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signatureValue }
        var certBody = try certificate.sequenceContent()
        let tbs = try certBody.readElement()
        self.signatureAlgorithmOid = try Self.algorithmOid(certBody.readElement())
        _ = try certBody.readElement().bitStringBytes() // signatureValue (verified by SecTrust)

        let fields = try Self.tbsFields(tbs)
        self.tbsSignatureAlgorithmOid = fields.signatureAlgorithmOid
        self.notBefore = fields.notBefore
        self.notAfter = fields.notAfter
        self.subjectPublicKeyAlgorithmOid = fields.publicKeyAlgorithmOid
        self.subjectPublicKeyCurveOid = fields.publicKeyCurveOid
        self.extensions = fields.extensions
    }

    // MARK: - Field parsers

    /// Reads the fields of `TBSCertificate` that the allow-lists need. Issuer, subject, serial, and
    /// version are read only to reach the fields that follow — `SecTrust` validates them.
    private static func tbsFields(_ tbs: Asn1DerParser.Element) throws -> TBSFields {
        var body = try tbs.sequenceContent()

        var field = try body.readElement()
        if field.isContext(0) { field = try body.readElement() } // optional [0] version
        try field.require(Asn1DerParser.Tag.integer) // serialNumber

        let signatureAlgorithmOid = try algorithmOid(body.readElement())
        _ = try body.readElement().encoded // issuer
        let (notBefore, notAfter) = try validity(body.readElement())
        _ = try body.readElement().encoded // subject
        let (publicKeyAlgorithmOid, publicKeyCurveOid) = try subjectPublicKeyInfo(body.readElement())

        // Only the [3] extensions wrapper is needed from the remaining optional fields.
        var extensions: [Extension] = []
        while !body.isAtEnd {
            let element = try body.readElement()
            if element.isContext(3) { extensions = try Self.extensions(element) }
        }

        return TBSFields(
            signatureAlgorithmOid: signatureAlgorithmOid,
            notBefore: notBefore,
            notAfter: notAfter,
            publicKeyAlgorithmOid: publicKeyAlgorithmOid,
            publicKeyCurveOid: publicKeyCurveOid,
            extensions: extensions
        )
    }

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

    /// Reads `SubjectPublicKeyInfo ::= SEQUENCE { algorithm AlgorithmIdentifier, subjectPublicKey
    /// BIT STRING }`, returning the algorithm OID and its optional named-curve parameter OID.
    private static func subjectPublicKeyInfo(
        _ element: Asn1DerParser.Element
    ) throws -> (algorithmOid: String, curveOid: String?) {
        var body = try element.sequenceContent()
        var algorithm = try body.readElement().sequenceContent()
        _ = try body.readElement().bitStringBytes() // subjectPublicKey (verified by SecTrust)

        let algorithmOid = try algorithm.readElement().objectIdentifier()
        var curveOid: String?
        if !algorithm.isAtEnd {
            let parameters = try algorithm.readElement()
            if parameters.tag == Asn1DerParser.Tag.objectIdentifier {
                curveOid = try parameters.objectIdentifier()
            }
        }
        return (algorithmOid, curveOid)
    }

    /// Reads `Extensions` from the `[3] EXPLICIT` wrapper: a SEQUENCE OF Extension.
    private static func extensions(_ wrapper: Asn1DerParser.Element) throws -> [Extension] {
        var explicitBody = wrapper.parseContent()
        var sequence = try explicitBody.readElement().sequenceContent()

        var result: [Extension] = []
        while !sequence.isAtEnd {
            result.append(try parseExtension(sequence.readElement()))
        }
        return result
    }

    /// Reads one `Extension ::= SEQUENCE { extnID OID, critical BOOLEAN DEFAULT FALSE,
    /// extnValue OCTET STRING }`.
    private static func parseExtension(_ element: Asn1DerParser.Element) throws -> Extension {
        var body = try element.sequenceContent()
        let oid = try body.readElement().objectIdentifier()

        var next = try body.readElement()
        var critical = false
        if next.tag == Asn1DerParser.Tag.boolean {
            critical = try decodeBoolean(next.content)
            next = try body.readElement()
        }
        return Extension(oid: oid, critical: critical, value: try next.octetStringBytes())
    }

    /// Decodes a DER BOOLEAN: a single octet, `0xFF` = TRUE, `0x00` = FALSE. Any other byte or
    /// length is a non-canonical encoding and is rejected rather than defaulted to FALSE.
    private static func decodeBoolean(_ content: Data) throws -> Bool {
        guard content.count == 1, let byte = content.first else {
            throw CoseVerificationFailure.untrustedCertificate
        }
        switch byte {
        case 0xFF: return true
        case 0x00: return false
        default: throw CoseVerificationFailure.untrustedCertificate
        }
    }
}
