@testable import ISOModelsOld
import Testing

@Suite
struct CurveTests {
    /// Registry is available on IANA.org.
    /// https://www.iana.org/assignments/cose/cose.xhtml
    @Test("Curve can be represented as an unsigned int as defined in the COSE Elliptic Curves registry")
    func rawValues() async throws {
        // These values were defined in RFC-9053:
        // https://www.rfc-editor.org/rfc/rfc9053.html
        #expect(Curve.p256.rawValue == 1)
        #expect(Curve.p384.rawValue == 2)
        #expect(Curve.p521.rawValue == 3)
        #expect(Curve.x25519.rawValue == 4)
        #expect(Curve.x448.rawValue == 5)
        #expect(Curve.ed25519.rawValue == 6)
        #expect(Curve.ed448.rawValue == 7)

        // These values were defined in RFC-8812:
        #expect(Curve.secp256k1.rawValue == 8)

        // These values were defined in ISO/IEC 18013-5
        #expect(Curve.brainpoolP256r1.rawValue == 256)
        #expect(Curve.brainpoolP320r1.rawValue == 257)
        #expect(Curve.brainpoolP384r1.rawValue == 258)
        #expect(Curve.brainpoolP512r1.rawValue == 259)
    }

    @Test("Curve has expected type")
    func keyType() async throws {
        #expect(Curve.p256.keyType == .ec2)
        #expect(Curve.p384.keyType == .ec2)
        #expect(Curve.p521.keyType == .ec2)
        #expect(Curve.x25519.keyType == .okp)
        #expect(Curve.x448.keyType == .okp)
        #expect(Curve.ed25519.keyType == .okp)
        #expect(Curve.ed448.keyType == .okp)
        #expect(Curve.secp256k1.keyType == .ec2)
        #expect(Curve.brainpoolP256r1.keyType == .ec2)
        #expect(Curve.brainpoolP320r1.keyType == .ec2)
        #expect(Curve.brainpoolP384r1.keyType == .ec2)
        #expect(Curve.brainpoolP512r1.keyType == .ec2)
    }
}
