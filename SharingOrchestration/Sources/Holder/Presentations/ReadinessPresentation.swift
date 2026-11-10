import Foundation
import SharingPrerequisiteGate

public struct ReadinessPresentation: Equatable, Hashable, Sendable {
    public let missingPrerequisites: [MissingPrerequisite]
    public let cancelRequiresConfirmation: Bool?

    public init(
        missingPrerequisites: [MissingPrerequisite],
        cancelRequiresConfirmation: Bool?
    ) {
        self.missingPrerequisites = missingPrerequisites
        self.cancelRequiresConfirmation = cancelRequiresConfirmation
    }
}
