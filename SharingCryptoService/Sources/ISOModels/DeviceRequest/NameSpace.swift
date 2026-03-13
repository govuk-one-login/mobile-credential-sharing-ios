import SwiftCBOR

public struct NameSpace: Equatable, Hashable, Sendable {
    public let name: String
    public let elements: [DataElement]
    
    init(name: String, cbor: CBOR) throws {
        self.name = name

        guard case let .map(elements) = cbor else {
            throw DeviceRequestError.nameSpaceWasIncorrectlyStructured
        }

        self.elements = try elements.map {
            guard case .utf8String(let element) = $0,
                  case .boolean(let intentToRetain) = $1
            else {
                throw DeviceRequestError.nameSpaceWasIncorrectlyStructured
            }

            return DataElement(identifier: element, intentToRetain: intentToRetain)
        }
    }
}

public struct DataElement: Equatable, Hashable, Sendable {
    public let identifier: String
    public let intentToRetain: Bool
}
