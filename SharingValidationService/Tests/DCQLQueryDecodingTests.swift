import Foundation
@testable import SharingValidationService
import Testing

@Suite("DCQLQuery Decoding Tests")
struct DCQLQueryDecodingTests {

    // MARK: - Happy Path

    @Test("Decodes minimal valid DCQL query with single mso_mdoc credential")
    func decodesMinimalQuery() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "mdl_credential",
                    "format": "mso_mdoc",
                    "meta": { "doctype_value": "org.iso.18013.5.1.mDL" },
                    "claims": [
                        { "path": ["org.iso.18013.5.1", "family_name"] }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials.count == 1)
        #expect(query.credentials[0].id == "mdl_credential")
        #expect(query.credentials[0].format == "mso_mdoc")
        #expect(query.credentials[0].meta?.doctypeValue == "org.iso.18013.5.1.mDL")
        #expect(query.credentials[0].claims?.count == 1)
        #expect(query.credentials[0].claims?[0].path == ["org.iso.18013.5.1", "family_name"])
        #expect(query.credentialSets == nil)
    }

    @Test("Decodes DCQL query with credential_sets")
    func decodesWithCredentialSets() throws {
        let json = """
        {
            "credentials": [
                { "id": "cred_a", "format": "mso_mdoc" },
                { "id": "cred_b", "format": "mso_mdoc" }
            ],
            "credential_sets": [
                { "options": [["cred_a"], ["cred_b"]], "required": true }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentialSets?.count == 1)
        #expect(query.credentialSets?[0].options == [["cred_a"], ["cred_b"]])
        #expect(query.credentialSets?[0].required == true)
    }

    @Test("Decodes DCQL query with claims and claim_sets")
    func decodesClaimsAndClaimSets() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "mdl",
                    "format": "mso_mdoc",
                    "claims": [
                        { "id": "name", "path": ["org.iso.18013.5.1", "family_name"] },
                        { "id": "age", "path": ["org.iso.18013.5.1", "age_over_18"] }
                    ],
                    "claim_sets": [["name"], ["name", "age"]]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        let credential = query.credentials[0]
        #expect(credential.claims?.count == 2)
        #expect(credential.claims?[0].id == "name")
        #expect(credential.claims?[1].id == "age")
        #expect(credential.claimSets == [["name"], ["name", "age"]])
    }

    @Test("Decodes ClaimValue string correctly")
    func decodesStringClaimValue() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "c1",
                    "format": "mso_mdoc",
                    "claims": [
                        { "path": ["ns", "elem"], "values": ["expected_value"] }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials[0].claims?[0].values == [.string("expected_value")])
    }

    @Test("Decodes ClaimValue int correctly")
    func decodesIntClaimValue() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "c1",
                    "format": "mso_mdoc",
                    "claims": [
                        { "path": ["ns", "elem"], "values": [42] }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials[0].claims?[0].values == [.int(42)])
    }

    @Test("Decodes ClaimValue bool correctly")
    func decodesBoolClaimValue() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "c1",
                    "format": "mso_mdoc",
                    "claims": [
                        { "path": ["ns", "elem"], "values": [true] }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials[0].claims?[0].values == [.bool(true)])
    }

    @Test("Decodes CredentialMeta with doctype_value")
    func decodesCredentialMeta() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "c1",
                    "format": "mso_mdoc",
                    "meta": { "doctype_value": "org.iso.18013.5.1.mDL" }
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials[0].meta?.doctypeValue == "org.iso.18013.5.1.mDL")
    }

    @Test("Handles missing optional fields gracefully")
    func handlesMissingOptionalFields() throws {
        let json = """
        {
            "credentials": [
                { "id": "c1", "format": "mso_mdoc" }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)

        #expect(query.credentials[0].meta == nil)
        #expect(query.credentials[0].claims == nil)
        #expect(query.credentials[0].claimSets == nil)
        #expect(query.credentialSets == nil)
    }

    @Test("Throws when credentials array is missing")
    func throwsWhenCredentialsMissing() {
        let json = """
        { "credential_sets": [] }
        """
        let data = Data(json.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(DCQLQuery.self, from: data)
        }
    }

    @Test("Decodes multiple claim values of different types")
    func decodesMultipleClaimValueTypes() throws {
        let json = """
        {
            "credentials": [
                {
                    "id": "c1",
                    "format": "mso_mdoc",
                    "claims": [
                        { "path": ["ns", "elem"], "values": ["text", 123, true, 3.14] }
                    ]
                }
            ]
        }
        """
        let data = Data(json.utf8)

        let query = try JSONDecoder().decode(DCQLQuery.self, from: data)
        let values = try #require(query.credentials[0].claims?[0].values)

        #expect(values[0] == .string("text"))
        #expect(values[1] == .int(123))
        #expect(values[2] == .bool(true))
        #expect(values[3] == .double(3.14))
    }
}
