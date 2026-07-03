import CryptoKit
import Foundation
@testable import SharingCryptoService
import Testing

@Suite("JWTSignatureVerifier Tests")
struct JWTSignatureVerifierTests {
    let sut = JWTSignatureVerifier()
    let helper = JWTTestHelper()

    // MARK: - Happy Path

    @Test("Verifies a valid ES256 JWT signed with x5c leaf certificate")
    func verifiesValidJWT() throws {
        let payload = Data(#"{"sub":"user","iss":"verifier"}"#.utf8)
        let jwt = try helper.sign(payload: payload)

        let result = try sut.verify(jwt: jwt)

        #expect(result.payloadData == payload)
        #expect(!result.headerData.isEmpty)
    }

    @Test("Returns decoded header data from a valid JWT")
    func returnsDecodedHeader() throws {
        let payload = Data(#"{"test":true}"#.utf8)
        let jwt = try helper.sign(payload: payload)

        let result = try sut.verify(jwt: jwt)

        let header = try JSONSerialization.jsonObject(with: result.headerData) as? [String: Any]
        #expect(header?["alg"] as? String == "ES256")
        #expect(header?["x5c"] != nil)
    }

    @Test("Returns empty SANs when leaf certificate has no SAN extension")
    func returnsEmptySANsWhenAbsent() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.sign(payload: payload)

        let result = try sut.verify(jwt: jwt)

        #expect(result.leafCertificateSANs.isEmpty)
    }

    // MARK: - Subject Alternative Names

    @Test("Extracts a single dNSName SAN from the leaf certificate")
    func extractsSingleDNSName() throws {
        let sanHelper = JWTTestHelper(dnsNames: ["verifier.example.com"])
        let jwt = try sanHelper.sign(payload: Data(#"{"sub":"user"}"#.utf8))

        let result = try sut.verify(jwt: jwt)

        #expect(result.leafCertificateSANs == ["verifier.example.com"])
    }

    @Test("Extracts multiple dNSName SANs preserving order")
    func extractsMultipleDNSNames() throws {
        let names = ["a.example.com", "verifier.example.com", "b.example.com"]
        let sanHelper = JWTTestHelper(dnsNames: names)
        let jwt = try sanHelper.sign(payload: Data(#"{"sub":"user"}"#.utf8))

        let result = try sut.verify(jwt: jwt)

        #expect(result.leafCertificateSANs == names)
    }

    // MARK: - Tampered Payload

    @Test("Throws invalidSignature when payload has been tampered with")
    func throwsInvalidSignatureForTamperedPayload() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.sign(payload: payload)

        let parts = jwt.split(separator: ".")
        let tamperedPayload = Data(#"{"sub":"attacker"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        let tamperedJWT = "\(parts[0]).\(tamperedPayload).\(parts[2])"

        #expect(throws: JWTVerificationError.invalidSignature) {
            try sut.verify(jwt: tamperedJWT)
        }
    }

    // MARK: - Tampered Signature

    @Test("Throws invalidSignature when signature bytes are altered")
    func throwsInvalidSignatureForTamperedSignature() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.sign(payload: payload)

        var parts = jwt.split(separator: ".").map(String.init)
        // Flip a character in the signature
        var sigChars = Array(parts[2])
        sigChars[0] = sigChars[0] == "A" ? "B" : "A"
        parts[2] = String(sigChars)

        let tamperedJWT = parts.joined(separator: ".")

        #expect {
            try sut.verify(jwt: tamperedJWT)
        } throws: { error in
            error as? JWTVerificationError == .invalidSignature
        }
    }

    // MARK: - Wrong Algorithm

    @Test("Throws unsupportedAlgorithm when header specifies RS256")
    func throwsUnsupportedAlgorithmForRS256() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let headerJSON = Data(#"{"alg":"RS256","typ":"JWT","x5c":["AAAA"]}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.unsupportedAlgorithm("RS256")) {
            try sut.verify(jwt: jwt)
        }
    }

    @Test("Throws unsupportedAlgorithm when alg field is missing")
    func throwsUnsupportedAlgorithmWhenMissing() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let headerJSON = Data(#"{"typ":"JWT","x5c":["AAAA"]}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.unsupportedAlgorithm("none")) {
            try sut.verify(jwt: jwt)
        }
    }

    // MARK: - Wrong Type

    @Test("Throws unsupportedType when typ is not JWT")
    func throwsUnsupportedTypeForWrongType() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let headerJSON = Data(#"{"alg":"ES256","typ":"at+jwt","x5c":["AAAA"]}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.unsupportedType("at+jwt")) {
            try sut.verify(jwt: jwt)
        }
    }

    @Test("Throws unsupportedType when typ field is missing")
    func throwsUnsupportedTypeWhenMissing() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let headerJSON = Data(#"{"alg":"ES256","x5c":["AAAA"]}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.unsupportedType("none")) {
            try sut.verify(jwt: jwt)
        }
    }

    // MARK: - Missing x5c

    @Test("Throws missingX5CHeader when x5c is absent from header")
    func throwsMissingX5CHeader() throws {
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.sign(payload: payload, includeX5C: false)

        #expect(throws: JWTVerificationError.missingX5CHeader) {
            try sut.verify(jwt: jwt)
        }
    }

    // MARK: - Malformed JWT Structure

    @Test("Throws invalidStructure when JWT has only two segments")
    func throwsInvalidStructureForTwoSegments() {
        #expect(throws: JWTVerificationError.invalidStructure) {
            try sut.verify(jwt: "header.payload")
        }
    }

    @Test("Throws invalidStructure when JWT has four segments")
    func throwsInvalidStructureForFourSegments() {
        #expect(throws: JWTVerificationError.invalidStructure) {
            try sut.verify(jwt: "a.b.c.d")
        }
    }

    @Test("Throws invalidStructure when JWT is empty")
    func throwsInvalidStructureForEmptyString() {
        #expect(throws: JWTVerificationError.invalidStructure) {
            try sut.verify(jwt: "")
        }
    }

    // MARK: - Invalid Header Encoding

    @Test("Throws headerDecodingFailed when header is not valid base64url")
    func throwsHeaderDecodingFailedForInvalidBase64() {
        #expect(throws: JWTVerificationError.headerDecodingFailed) {
            try sut.verify(jwt: "!!!invalid!!!.cGF5bG9hZA.c2ln")
        }
    }

    @Test("Throws headerDecodingFailed when header is not valid JSON")
    func throwsHeaderDecodingFailedForNonJSON() {
        let notJSON = Data("not json at all".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")

        #expect(throws: JWTVerificationError.headerDecodingFailed) {
            try sut.verify(jwt: "\(notJSON).cGF5bG9hZA.c2ln")
        }
    }

    // MARK: - Invalid Certificate Data

    @Test("Throws invalidCertificateData when x5c contains non-base64 data")
    func throwsInvalidCertificateForBadBase64() throws {
        let headerJSON = Data(#"{"alg":"ES256","typ":"JWT","x5c":["!!!not-base64!!!"]}"#.utf8)
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.invalidCertificateData) {
            try sut.verify(jwt: jwt)
        }
    }

    @Test("Throws invalidCertificateData when x5c contains garbage bytes")
    func throwsInvalidCertificateForGarbageBytes() throws {
        let garbage = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01, 0x02, 0x03])
        let headerDict: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "x5c": [garbage.base64EncodedString()]
        ]
        let headerJSON = try JSONSerialization.data(withJSONObject: headerDict)
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.invalidCertificateData) {
            try sut.verify(jwt: jwt)
        }
    }

    @Test("Throws invalidCertificateData when x5c array is empty")
    func throwsMissingX5CForEmptyArray() throws {
        let headerJSON = Data(#"{"alg":"ES256","typ":"JWT","x5c":[]}"#.utf8)
        let payload = Data(#"{"sub":"user"}"#.utf8)
        let jwt = try helper.signWithCustomHeader(headerJSON, payload: payload)

        #expect(throws: JWTVerificationError.missingX5CHeader) {
            try sut.verify(jwt: jwt)
        }
    }
}
