import Foundation

public struct RemotePresentationSubmission: Encodable, Sendable, Equatable {
    public let id: String
    public let definitionID: String
    public let descriptorMap: [DescriptorMapEntry]

    public init(
        id: String,
        definitionID: String,
        descriptorMap: [DescriptorMapEntry]
    ) {
        self.id = id
        self.definitionID = definitionID
        self.descriptorMap = descriptorMap
    }

    enum CodingKeys: String, CodingKey {
        case id
        case definitionID = "definition_id"
        case descriptorMap = "descriptor_map"
    }
}

public struct DescriptorMapEntry: Encodable, Sendable, Equatable {
    public let id: String
    public let format: String
    public let path: String

    public init(id: String, format: String, path: String) {
        self.id = id
        self.format = format
        self.path = path
    }
}
