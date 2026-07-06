@testable import SharingCryptoService
@testable import SharingOrchestration
import SharingValidationService
import Testing

@Suite("DCQLMapper Tests")
struct DCQLMapperTests {
    let sut = DCQLMapper()

    private func credential(
        doctype: String? = "org.iso.18013.5.1.mDL",
        claims: [ClaimQuery]?
    ) -> CredentialQuery {
        CredentialQuery(
            id: "cred1",
            format: "mso_mdoc",
            meta: doctype.map { CredentialMeta(doctypeValue: $0) },
            claims: claims,
            claimSets: nil
        )
    }

    private func claim(_ path: [String], intentToRetain: Bool = false) -> ClaimQuery {
        ClaimQuery(id: nil, path: path, values: nil, intentToRetain: intentToRetain)
    }

    // MARK: - Happy Path

    @Test("Maps a standard mDL claim set to a single-namespace ItemsRequest")
    func mapsStandardClaimSet() throws {
        let credential = credential(claims: [
            claim(["org.iso.18013.5.1", "family_name"]),
            claim(["org.iso.18013.5.1", "given_name"])
        ])

        let itemsRequest = try sut.mapToItemsRequest(credential)

        #expect(itemsRequest.docType == .mdl)
        #expect(itemsRequest.nameSpaces.count == 1)
        #expect(itemsRequest.nameSpaces[0].name == "org.iso.18013.5.1")
        #expect(itemsRequest.nameSpaces[0].elements.map(\.identifier) == ["family_name", "given_name"])
    }

    @Test("Groups claims across namespaces preserving first-seen order")
    func groupsMultipleNamespaces() throws {
        let credential = credential(claims: [
            claim(["org.iso.18013.5.1", "family_name"]),
            claim(["org.iso.18013.5.1.aamva", "organ_donor"]),
            claim(["org.iso.18013.5.1", "given_name"])
        ])

        let itemsRequest = try sut.mapToItemsRequest(credential)

        #expect(itemsRequest.nameSpaces.map(\.name) == ["org.iso.18013.5.1", "org.iso.18013.5.1.aamva"])
        #expect(itemsRequest.nameSpaces[0].elements.map(\.identifier) == ["family_name", "given_name"])
        #expect(itemsRequest.nameSpaces[1].elements.map(\.identifier) == ["organ_donor"])
    }

    @Test("Carries intent_to_retain through to the data element")
    func carriesIntentToRetain() throws {
        let credential = credential(claims: [
            claim(["org.iso.18013.5.1", "portrait"], intentToRetain: true),
            claim(["org.iso.18013.5.1", "given_name"])
        ])

        let itemsRequest = try sut.mapToItemsRequest(credential)

        let elements = itemsRequest.nameSpaces[0].elements
        #expect(elements[0] == DataElement(identifier: "portrait", intentToRetain: true))
        #expect(elements[1] == DataElement(identifier: "given_name", intentToRetain: false))
    }

    // MARK: - Errors

    @Test("Throws missingDoctype when meta has no doctype_value")
    func throwsMissingDoctype() {
        let credential = credential(doctype: nil, claims: [
            claim(["org.iso.18013.5.1", "family_name"])
        ])

        #expect(throws: DCQLMappingError.missingDoctype) {
            try sut.mapToItemsRequest(credential)
        }
    }

    @Test("Throws unsupportedDoctype for an unknown doctype value")
    func throwsUnsupportedDoctype() {
        let credential = credential(doctype: "com.example.unknown", claims: [
            claim(["org.iso.18013.5.1", "family_name"])
        ])

        #expect(throws: DCQLMappingError.unsupportedDoctype("com.example.unknown")) {
            try sut.mapToItemsRequest(credential)
        }
    }

    @Test("Throws invalidClaimPath when a path does not have exactly two elements")
    func throwsInvalidClaimPath() {
        let credential = credential(claims: [
            claim(["org.iso.18013.5.1"])
        ])

        #expect(throws: DCQLMappingError.invalidClaimPath(["org.iso.18013.5.1"])) {
            try sut.mapToItemsRequest(credential)
        }
    }

    @Test("Throws noClaims when the credential has no claims")
    func throwsNoClaims() {
        let credential = credential(claims: nil)

        #expect(throws: DCQLMappingError.noClaims) {
            try sut.mapToItemsRequest(credential)
        }
    }
}
