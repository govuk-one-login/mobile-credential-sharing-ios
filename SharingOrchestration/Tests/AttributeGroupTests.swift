@testable import SharingOrchestration
import Testing

@Suite("MDLAttribute Tests")
struct MDLAttributeTests {

    @Test("All standard attributes return correct identifiers")
    func standardAttributeIdentifiers() {
        #expect(MDLAttribute.familyName.identifier == "family_name")
        #expect(MDLAttribute.givenName.identifier == "given_name")
        #expect(MDLAttribute.birthDate.identifier == "birth_date")
        #expect(MDLAttribute.issueDate.identifier == "issue_date")
        #expect(MDLAttribute.expiryDate.identifier == "expiry_date")
        #expect(MDLAttribute.issuingCountry.identifier == "issuing_country")
        #expect(MDLAttribute.issuingAuthority.identifier == "issuing_authority")
        #expect(MDLAttribute.documentNumber.identifier == "document_number")
        #expect(MDLAttribute.portrait.identifier == "portrait")
        #expect(MDLAttribute.birthPlace.identifier == "birth_place")
        #expect(MDLAttribute.drivingPrivileges.identifier == "driving_privileges")
        #expect(MDLAttribute.unDistinguishingSign.identifier == "un_distinguishing_sign")
        #expect(MDLAttribute.residentAddress.identifier == "resident_address")
        #expect(MDLAttribute.residentPostalCode.identifier == "resident_postal_code")
        #expect(MDLAttribute.residentCity.identifier == "resident_city")
    }

    @Test("ageOver returns correct identifier for valid values")
    func ageOverIdentifiers() {
        #expect(MDLAttribute.ageOver(0).identifier == "age_over_0")
        #expect(MDLAttribute.ageOver(18).identifier == "age_over_18")
        #expect(MDLAttribute.ageOver(21).identifier == "age_over_21")
        #expect(MDLAttribute.ageOver(99).identifier == "age_over_99")
    }

    @Test("ageOver cases with different values are not equal")
    func ageOverEquality() {
        #expect(MDLAttribute.ageOver(18) != MDLAttribute.ageOver(21))
        #expect(MDLAttribute.ageOver(18) == MDLAttribute.ageOver(18))
    }
}

@Suite("GBMDLAttribute Tests")
struct GBMDLAttributeTests {

    @Test("All GB attributes return correct identifiers")
    func gbAttributeIdentifiers() {
        #expect(GBMDLAttribute.welshLicence.identifier == "welsh_licence")
        #expect(GBMDLAttribute.title.identifier == "title")
        #expect(GBMDLAttribute.provisionalDrivingPrivileges.identifier == "provisional_driving_privileges")
    }

    @Test("Raw values match identifiers")
    func rawValuesMatchIdentifiers() {
        for attribute in GBMDLAttribute.allCases {
            #expect(attribute.rawValue == attribute.identifier)
        }
    }
}

@Suite("AttributeGroup Tests")
struct AttributeGroupTests {

    @Test("Init returns nil when both collections are empty")
    func initReturnsNilWhenEmpty() {
        let group = AttributeGroup(mdlAttributes: [], gbMdlAttributes: [])
        #expect(group == nil)
    }

    @Test("Init succeeds with only mdlAttributes")
    func initSucceedsWithMDLOnly() {
        let group = AttributeGroup(
            mdlAttributes: [.init(attribute: .givenName, intentToRetain: true)]
        )
        #expect(group != nil)
        #expect(group?.mdlAttributes.count == 1)
        #expect(group?.gbMdlAttributes.isEmpty == true)
    }

    @Test("Init succeeds with only gbMdlAttributes")
    func initSucceedsWithGBOnly() {
        let group = AttributeGroup(
            gbMdlAttributes: [.init(attribute: .title, intentToRetain: false)]
        )
        #expect(group != nil)
        #expect(group?.mdlAttributes.isEmpty == true)
        #expect(group?.gbMdlAttributes.count == 1)
    }

    @Test("Init succeeds with both collections")
    func initSucceedsWithBoth() {
        let group = AttributeGroup(
            mdlAttributes: [.init(attribute: .portrait, intentToRetain: false)],
            gbMdlAttributes: [.init(attribute: .title, intentToRetain: true)]
        )
        #expect(group != nil)
        #expect(group?.mdlAttributes.count == 1)
        #expect(group?.gbMdlAttributes.count == 1)
    }

    @Test("DocType defaults to mDL")
    func defaultDocType() {
        let group = AttributeGroup(
            mdlAttributes: [.init(attribute: .givenName, intentToRetain: true)]
        )
        #expect(group?.docType == .mdl)
    }

    @Test("IntentToRetain is preserved on attributes")
    func intentToRetainPreserved() throws {
        let group = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .givenName, intentToRetain: true),
                .init(attribute: .portrait, intentToRetain: false)
            ]
        ))
        #expect(group.mdlAttributes[0].intentToRetain == true)
        #expect(group.mdlAttributes[1].intentToRetain == false)
    }

    @Test("Namespace raw values match ISO spec")
    func namespaceRawValues() {
        #expect(AttributeGroup.Namespace.standard.rawValue == "org.iso.18013.5.1")
        #expect(AttributeGroup.Namespace.gb.rawValue == "org.iso.18013.5.1.GB")
    }
}
