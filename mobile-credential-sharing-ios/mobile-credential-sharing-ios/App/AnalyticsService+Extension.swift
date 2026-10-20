import Foundation
import GAnalytics
import GDSAnalytics
import Logging

extension AnalyticsService {
    public func trackButtonEvent(_ event: Event) {
        logEvent(
            AnalyticsLoggableEvent(name: event.name.rawValue),
            parameters: Dictionary.screenViewDefaults.merging(event.parameters as [String: Any]) { _, eventValue in
                eventValue
            }
        )
    }

    public func trackScreenEvent(_ event: LoggableEvent) {
        logEvent(event, parameters: Dictionary.screenViewDefaults)
    }
}

private struct AnalyticsLoggableEvent: LoggableEvent {
    let name: String
}

public struct AnalyticsData {
    public let key: String
    public let value: Any
}

extension AnalyticsData {
    static let savedDocType = AnalyticsData(key: "saved_doc_type", value: "undefined")
    static let publishingOrg = AnalyticsData(
        key: "primary_publishing_organisation",
        value: "government digital service - digital identity")
    static let organisation = AnalyticsData(key: "organisation", value: "<OT1056>")
    static let taxonomyLevel1 = AnalyticsData(key: "taxonomy_level1", value: "one login mobile application")
    static let taxonomyLevel2 = AnalyticsData(key: "taxonomy_level2", value: "document checking application")
    static let taxonomyLevel3 = AnalyticsData(key: "taxonomy_level3", value: "driving licence cri")
    static let language = AnalyticsData(key: "language", value: NSLocale.current.identifier)

    static var screenViewDefaults: [AnalyticsData] = [
        savedDocType,
        publishingOrg,
        organisation,
        taxonomyLevel1,
        taxonomyLevel2,
        taxonomyLevel3,
        language
    ]
}

extension Dictionary where Key == String, Value == Any {
    static let screenViewDefaults: [String: Any] = AnalyticsData.screenViewDefaults.reduce(into: [:]) { result, analyticsData in
        result[analyticsData.key] = analyticsData.value
    }
}
