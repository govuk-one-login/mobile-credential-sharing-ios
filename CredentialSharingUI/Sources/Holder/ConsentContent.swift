import SharingOrchestration

enum ConsentVariant: Equatable {
    case noneKept
    case allKept
    case someKept
}

struct ConsentSection: Equatable {
    let heading: String?
    let items: [String]
    let footnote: String?
}

struct ConsentContent {
    static let title = "Review what you’ll share"
    static let whatYoullShareHeading = "What you’ll share"
    static let cancelButtonTitle = "Cancel and go back to documents"

    let variant: ConsentVariant
    let organisationSentence: String
    let readAboutButtonTitle: String
    let summary: String
    let sections: [ConsentSection]
    let agreeButtonTitle: String

    init(presentation: ConsentPresentation) {
        let name = presentation.dvsName
        // The DVS name used at the end of a sentence, where we add the full stop ourselves.
        let sentenceEndName = Self.normaliseDvsName(name)
        let kept = presentation.attributes.filter(\.intentToRetain).map(\.displayLabel)
        let notKept = presentation.attributes.filter { !$0.intentToRetain }.map(\.displayLabel)
        let count = presentation.attributes.count
        let details = count == 1 ? "detail" : "details"

        organisationSentence = "The person doing the check is using an approved app powered by \(sentenceEndName)."
        readAboutButtonTitle = "Read about \(name) and their privacy notice"
        summary = "You’ll share \(count) \(details) from your \(presentation.documentType.displayLabel)"
        agreeButtonTitle = "Agree and share \(count) \(details)"

        switch (kept.isEmpty, notKept.isEmpty) {
        case (true, _):
            variant = .noneKept
            sections = [ConsentSection(
                heading: nil,
                items: notKept,
                footnote: "These details will only be used for this check. They will not be saved."
            )]
        case (false, true):
            variant = .allKept
            sections = [ConsentSection(
                heading: nil,
                items: kept,
                footnote: "\(sentenceEndName) will keep these details as a record of this check."
            )]
        case (false, false):
            variant = .someKept
            sections = [
                ConsentSection(heading: "\(name) will keep these details as a record of this check:", items: kept, footnote: nil),
                ConsentSection(heading: "\(name) will not keep:", items: notKept, footnote: nil)
            ]
        }
    }

    static func normaliseDvsName(_ name: String) -> String {
        var trimmed = name
        while trimmed.hasSuffix(".") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }
}
