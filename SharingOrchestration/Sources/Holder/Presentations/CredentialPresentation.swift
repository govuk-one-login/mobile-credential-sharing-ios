import Foundation
import UIKit

public struct ConsentPresentation: Equatable, Hashable, Sendable {
    public let dvsName: String
    public let documentType: DocumentType
    public let attributes: [ConsentAttribute]
    public let privacyPolicyURL: URL

    public init(
        dvsName: String,
        documentType: DocumentType,
        attributes: [ConsentAttribute],
        privacyPolicyURL: URL
    ) {
        self.dvsName = dvsName
        self.documentType = documentType
        self.attributes = attributes
        self.privacyPolicyURL = privacyPolicyURL
    }
}

public struct ConsentAttribute: Equatable, Hashable, Sendable {
    public let namespace: String
    public let displayLabel: String
    public let intentToRetain: Bool

    public init(
        namespace: String,
        displayLabel: String,
        intentToRetain: Bool
    ) {
        self.namespace = namespace
        self.displayLabel = displayLabel
        self.intentToRetain = intentToRetain
    }
}

public struct DocumentType: Equatable, Hashable, Sendable {
    public let displayLabel: String
    public let documentIcon: UIImage

    public init(
        displayLabel: String,
        documentIcon: UIImage
    ) {
        self.displayLabel = displayLabel
        self.documentIcon = documentIcon
    }
}
