import Foundation
@testable import SharingValidationService
import Testing

@Suite("VerifiedRequestObject JWT decoding Tests")
struct VerifiedRequestObjectDecodingTests {
    private let header = Data(#"{"typ":"oauth-authz-req+jwt","alg":"ES256"}"#.utf8)

    private func fullPayload() -> Data {
        let json = """
        {
            "aud": "https://self-issued.me/v2",
            "client_id": "x509_san_dns:verifier.example.com",
            "response_type": "vp_token",
            "response_mode": "direct_post.jwt",
            "response_uri": "https://verifier.example.com/response",
            "nonce": "valid_nonce",
            "state": "session.state",
            "dcql_query": { "credentials": [{ "id": "c1", "format": "mso_mdoc" }] },
            "client_metadata": { "jwks": { "keys": [] } }
        }
        """
        return Data(json.utf8)
    }

    // MARK: - Happy Path

    @Test("Maps all header and payload claims into the request object")
    func mapsAllClaims() throws {
        let sut = try VerifiedRequestObject(
            headerData: header,
            payloadData: fullPayload(),
            leafCertificateSANs: ["verifier.example.com"]
        )

        #expect(sut.headerTyp == "oauth-authz-req+jwt")
        #expect(sut.aud == "https://self-issued.me/v2")
        #expect(sut.clientID == "x509_san_dns:verifier.example.com")
        #expect(sut.responseType == "vp_token")
        #expect(sut.responseMode == "direct_post.jwt")
        #expect(sut.responseURI == "https://verifier.example.com/response")
        #expect(sut.nonce == "valid_nonce")
        #expect(sut.state == "session.state")
        #expect(sut.leafCertificateSANs == ["verifier.example.com"])
    }

    @Test("Re-serialises dcql_query into decodable data")
    func reserialisesDCQLQuery() throws {
        let sut = try VerifiedRequestObject(
            headerData: header,
            payloadData: fullPayload(),
            leafCertificateSANs: []
        )

        let dcqlData = try #require(sut.dcqlQueryData)
        let query = try JSONDecoder().decode(DCQLQuery.self, from: dcqlData)
        #expect(query.credentials.count == 1)
        #expect(query.credentials[0].format == "mso_mdoc")
    }

    @Test("Re-serialises client_metadata into data")
    func reserialisesClientMetadata() throws {
        let sut = try VerifiedRequestObject(
            headerData: header,
            payloadData: fullPayload(),
            leafCertificateSANs: []
        )

        #expect(sut.clientMetadataData != nil)
    }

    @Test("Decoded object passes full validation")
    func decodedObjectPassesValidation() throws {
        let sut = try VerifiedRequestObject(
            headerData: header,
            payloadData: fullPayload(),
            leafCertificateSANs: ["verifier.example.com"]
        )
        let uriMetadata = URIMetadata(
            clientID: "x509_san_dns:verifier.example.com",
            clientIdentifierPrefix: .x509SanDns(identifier: "verifier.example.com"),
            responseType: "vp_token",
            nonce: "uri_nonce",
            requestURI: URL(string: "https://verifier.example.com/request")!
        )

        let result = try RequestValidator().validate(requestObject: sut, uriMetadata: uriMetadata)

        #expect(result.nonce == "valid_nonce")
    }

    // MARK: - Optional Fields

    @Test("Absent optional claims decode to nil")
    func absentClaimsAreNil() throws {
        let payload = Data(#"{"aud":"https://self-issued.me/v2"}"#.utf8)

        let sut = try VerifiedRequestObject(
            headerData: header,
            payloadData: payload,
            leafCertificateSANs: []
        )

        #expect(sut.aud == "https://self-issued.me/v2")
        #expect(sut.clientID == nil)
        #expect(sut.responseMode == nil)
        #expect(sut.redirectURI == nil)
        #expect(sut.state == nil)
        #expect(sut.dcqlQueryData == nil)
        #expect(sut.clientMetadataData == nil)
    }

    @Test("Absent typ header decodes to nil")
    func absentTypIsNil() throws {
        let headerWithoutTyp = Data(#"{"alg":"ES256"}"#.utf8)

        let sut = try VerifiedRequestObject(
            headerData: headerWithoutTyp,
            payloadData: fullPayload(),
            leafCertificateSANs: []
        )

        #expect(sut.headerTyp == nil)
    }

    // MARK: - Malformed Input

    @Test("Throws malformedRequestObjectHeader when header is not a JSON object")
    func throwsForMalformedHeader() {
        let badHeader = Data("not json".utf8)

        #expect(throws: ValidationError.malformedRequestObjectHeader) {
            try VerifiedRequestObject(
                headerData: badHeader,
                payloadData: fullPayload(),
                leafCertificateSANs: []
            )
        }
    }

    @Test("Throws malformedRequestObjectPayload when payload is not a JSON object")
    func throwsForMalformedPayload() {
        let badPayload = Data("[1,2,3]".utf8)

        #expect(throws: ValidationError.malformedRequestObjectPayload) {
            try VerifiedRequestObject(
                headerData: header,
                payloadData: badPayload,
                leafCertificateSANs: []
            )
        }
    }
}
