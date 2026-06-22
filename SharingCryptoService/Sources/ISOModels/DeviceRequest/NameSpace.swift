import SwiftCBOR

public struct NameSpace: Equatable, Hashable, Sendable {
    public let name: String
    public let elements: [DataElement]

    public init(name: String, elements: [DataElement]) {
        self.name = name
        self.elements = elements
    }

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

extension NameSpace: CBOREncodable {
    public func toCBOR(options: CBOROptions = CBOROptions()) -> CBOR {
        var map: [CBOR: CBOR] = [:]
        for element in elements {
            map[.utf8String(element.identifier)] = .boolean(element.intentToRetain)
        }
        return .map(map)
    }
}

public struct DataElement: Equatable, Hashable, Sendable {
    public let identifier: String
    public let intentToRetain: Bool

    public init(identifier: String, intentToRetain: Bool) {
        self.identifier = identifier
        self.intentToRetain = intentToRetain
    }
}
