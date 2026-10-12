import Foundation
import UIKit

public struct ConsentPresentation: Equatable, Hashable, Sendable {
    public let dvsName: String
    public let documentType: DocumentType
    public let attributes: [ConsentAttribute]
    public let privacyPolicyURL: URL
}

public struct ConsentAttribute: Equatable, Hashable, Sendable {
    public let namespace: String
    public let displayLabel: String
    public let intentToRetain: Bool
}

public struct DocumentType: Equatable, Hashable, Sendable {
    public let displayLabel: String
    public let documentIcon: UIImage
}
