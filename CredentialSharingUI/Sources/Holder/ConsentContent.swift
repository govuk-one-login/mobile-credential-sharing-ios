import Foundation
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
    static let title = localized("agreeToShareTitle")
    static let whatYoullShareHeading = localized("agreeToShareWhatYoullShareHeading")
    static let cancelButtonTitle = localized("agreeToShareCancelButton")

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
        let details = count == 1
            ? Self.localized("agreeToShareDetailSingular")
            : Self.localized("agreeToShareDetailPlural")

        organisationSentence = Self.localized("agreeToShareOrganisationSentence", sentenceEndName)
        readAboutButtonTitle = Self.localized("agreeToShareReadAboutButton", name)
        summary = Self.localized("agreeToShareSummary", count, details, presentation.documentType.displayLabel)
        agreeButtonTitle = Self.localized("agreeToShareAgreeButton", count, details)

        switch (kept.isEmpty, notKept.isEmpty) {
        case (true, _):
            variant = .noneKept
            sections = [ConsentSection(
                heading: nil,
                items: notKept,
                footnote: Self.localized("agreeToShareNoneKeptFootnote")
            )]
        case (false, true):
            variant = .allKept
            sections = [ConsentSection(
                heading: nil,
                items: kept,
                footnote: Self.localized("agreeToShareAllKeptFootnote", sentenceEndName)
            )]
        case (false, false):
            variant = .someKept
            sections = [
                ConsentSection(
                    heading: Self.localized("agreeToShareRetainedHeading", name),
                    items: kept,
                    footnote: nil
                ),
                ConsentSection(
                    heading: Self.localized("agreeToShareNotKeptHeading", name),
                    items: notKept,
                    footnote: nil
                )
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

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), bundle: .module)
    }

    private static func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(key), bundle: .module)
        return String(format: format, locale: .current, arguments: arguments)
    }
}
