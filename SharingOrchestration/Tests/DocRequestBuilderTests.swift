@testable import SharingCryptoService
@testable import SharingOrchestration
import SwiftCBOR
import Testing

@Suite("DocRequestBuilder Tests")
struct DocRequestBuilderTests {
    let docRequestBuilder = DocRequestBuilder()

    @Test("Maps AttributeGroup with single namespace to ItemsRequest")
    func singleNamespaceMapping() throws {
        // GIVEN
        let group = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .portrait, intentToRetain: false),
                .init(attribute: .ageOver(21), intentToRetain: false)
            ]
        ))

        // WHEN
        let docRequest = docRequestBuilder.build(from: group)
        let itemsRequest = docRequest.itemsRequest

        // THEN
        #expect(itemsRequest.docType == .mdl)
        #expect(itemsRequest.docType.rawValue == "org.iso.18013.5.1.mDL")
        #expect(itemsRequest.nameSpaces.count == 1)

        let nameSpace = try #require(itemsRequest.nameSpaces.first)
        #expect(nameSpace.name == "org.iso.18013.5.1")
        #expect(nameSpace.elements.count == 2)
        #expect(nameSpace.elements.contains(DataElement(identifier: "portrait", intentToRetain: false)))
        #expect(nameSpace.elements.contains(DataElement(identifier: "age_over_21", intentToRetain: false)))
    }

    @Test("Maps AttributeGroup with multiple namespaces to ItemsRequest")
    func multipleNamespaceMapping() throws {
        // GIVEN
        let group = try #require(AttributeGroup(
            mdlAttributes: [
                .init(attribute: .givenName, intentToRetain: true),
                .init(attribute: .ageOver(23), intentToRetain: true)
            ],
            gbMdlAttributes: [
                .init(attribute: .title, intentToRetain: false)
            ]
        ))

        // WHEN
        let docRequest = docRequestBuilder.build(from: group)
        let itemsRequest = docRequest.itemsRequest

        // THEN
        #expect(itemsRequest.docType == .mdl)
        #expect(itemsRequest.docType.rawValue == "org.iso.18013.5.1.mDL")
        #expect(itemsRequest.nameSpaces.count == 2)

        let standardNS = try #require(itemsRequest.nameSpaces.first { $0.name == "org.iso.18013.5.1" })
        #expect(standardNS.elements.count == 2)
        #expect(standardNS.elements.contains(DataElement(identifier: "given_name", intentToRetain: true)))
        #expect(standardNS.elements.contains(DataElement(identifier: "age_over_23", intentToRetain: true)))

        let gbNS = try #require(itemsRequest.nameSpaces.first { $0.name == "org.iso.18013.5.1.GB" })
        #expect(gbNS.elements.count == 1)
        #expect(gbNS.elements.contains(DataElement(identifier: "title", intentToRetain: false)))
    }

    @Test("ItemsRequest encodes to Tag 24 wrapped CBOR bytes that decode back")
    func cborEncodingAndTag24() throws {
        // GIVEN
        let itemsRequest = ItemsRequest(
            docType: .mdl,
            nameSpaces: [
                NameSpace(name: "org.iso.18013.5.1", elements: [
                    DataElement(identifier: "portrait", intentToRetain: false),
                    DataElement(identifier: "family_name", intentToRetain: true)
                ])
            ]
        )

        // WHEN - encode as Tag 24 (ItemsRequestBytes)
        let tag24CBOR = itemsRequest.asDataItem(options: CBOROptions())
        let encodedBytes = tag24CBOR.encode()

        // THEN - output is a Tag 24
        let decoded = try #require(try CBOR.decode(encodedBytes))
        guard case .tagged(let tag, .byteString(let innerBytes)) = decoded else {
            Issue.record("Expected Tag 24 wrapping a byte string")
            return
        }
        #expect(tag == .encodedCBORDataItem)

        // AND - decoding the inner byte string resolves back to the original structure
        let innerCBOR = try #require(try CBOR.decode(innerBytes))
        let decodedItemsRequest = try ItemsRequest(cbor: innerCBOR)
        #expect(decodedItemsRequest.docType == itemsRequest.docType)
        #expect(decodedItemsRequest.nameSpaces.count == itemsRequest.nameSpaces.count)

        let decodedNameSpace = try #require(decodedItemsRequest.nameSpaces.first)
        #expect(decodedNameSpace.name == "org.iso.18013.5.1")
        #expect(decodedNameSpace.elements.contains(DataElement(identifier: "portrait", intentToRetain: false)))
        #expect(decodedNameSpace.elements.contains(DataElement(identifier: "family_name", intentToRetain: true)))
    }

    @Test("DocRequest contains only itemsRequest key with Tag 24 bytes, readerAuth not populated")
    func docRequestConstruction() throws {
        // GIVEN
        let itemsRequest = ItemsRequest(
            docType: .mdl,
            nameSpaces: [
                NameSpace(name: "org.iso.18013.5.1", elements: [
                    DataElement(identifier: "given_name", intentToRetain: false)
                ])
            ]
        )

        // WHEN
        let docRequest = DocRequest(itemsRequest: itemsRequest)
        let encoded = docRequest.toCBOR(options: CBOROptions())

        // THEN - the CBOR map contains exactly one key-value pair
        guard case .map(let map) = encoded else {
            Issue.record("Expected CBOR map")
            return
        }
        #expect(map.count == 1)

        // AND - the only key is "itemsRequest" containing Tag 24 bytes
        let itemsRequestCBOR = try #require(map[CBOR.utf8String("itemsRequest")])
        guard case .tagged(let tag, .byteString(let innerBytes)) = itemsRequestCBOR else {
            Issue.record("Expected itemsRequest to be Tag 24 wrapped byte string")
            return
        }
        #expect(tag == .encodedCBORDataItem)

        // AND - the inner bytes decode back to the original ItemsRequest
        let innerCBOR = try #require(try CBOR.decode(innerBytes))
        let decoded = try ItemsRequest(cbor: innerCBOR)
        #expect(decoded.docType == .mdl)
        #expect(decoded.nameSpaces.first?.elements.first?.identifier == "given_name")

        // AND - readerAuth is not populated (defined in structure as optional)
        #expect(docRequest.readerAuth == nil)
        #expect(map[CBOR.utf8String("readerAuth")] == nil)
    }
}
