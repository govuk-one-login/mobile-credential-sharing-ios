import Foundation

public struct DeviceRequest {
    let version: String = "1.0"
    let docRequest: [DocRequest]
}

struct DocRequest {
    let itemsToRequest: ItemsToRequest
}

struct ItemsToRequest {
    let docType: DocType
    let nameSpaces: [NameSpace : [DataElementIdentifier : IntentToRetain]]
}

struct DocType {}

struct NameSpace: Hashable {}

typealias DataElementIdentifier = String
typealias IntentToRetain = Bool
