@testable import SharingCryptoService

enum MockDeviceRequest {
    static let standard = DeviceRequest(docRequests: [
        DocRequest(
            itemsRequest: ItemsRequest(
                docType: .mdl,
                nameSpaces: [
                    NameSpace(name: "org.iso.18013.5.1", elements: [
                        DataElement(identifier: "family_name", intentToRetain: true),
                        DataElement(identifier: "portrait", intentToRetain: false),
                        DataElement(identifier: "age_over_23", intentToRetain: false)
                    ]),
                    NameSpace(name: "org.iso.18013.5.1.GB", elements: [
                        DataElement(identifier: "title", intentToRetain: false)
                    ])
                ]
            )
        )
    ])
}
