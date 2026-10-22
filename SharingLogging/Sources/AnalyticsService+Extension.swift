import Foundation
import GDSAnalytics
import Logging

extension AnalyticsService {
    public func trackButtonEvent(_ event: Event) {
        logEvent(
            AnalyticsEvent(name: event.name.rawValue),
            parameters: (AnalyticsData.screenViewDefaultsDictionary as [String: Any])
                .merging(event.parameters as [String: Any]) { _, eventValue in
                    eventValue
                }
        )
    }

    public func trackScreenEvent(
        _ event: LoggableEvent,
        title: String,
        screenClass: ScreenClass,
        screenID: String,
        savedDocType: String? = nil,
        error: LoggableError? = nil
    ) {
        var parameters = AnalyticsData.screenViewDefaultsDictionary as [String: Any]
        parameters[ScreenViewParameter.screenName.rawValue] = title.formattedAsAnalyticsParameter
        parameters[ScreenViewParameter.screenClass.rawValue] = screenClass.rawValue
        parameters[ScreenViewParameter.screenID.rawValue] = screenID.formattedAsAnalyticsParameter
        parameters[ScreenViewParameter.isError.rawValue] = String(event.name == ScreenViewEventName.screenViewError.rawValue)

        if let savedDocType {
            parameters[ScreenViewParameter.savedDocType.rawValue] = savedDocType.formattedAsAnalyticsParameter
        }

        if let error {
            if let reason = error.reason?.formattedAsAnalyticsParameter {
                parameters[ScreenViewParameter.reason.rawValue] = reason
            }
            if let endpoint = error.endpoint?.formattedAsAnalyticsParameter {
                parameters[ScreenViewParameter.endpoint.rawValue] = endpoint
            }
            if let status = error.statusCode?.formattedAsAnalyticsParameter {
                parameters[ScreenViewParameter.status.rawValue] = status
            }
            if let hash = error.hash?.formattedAsAnalyticsParameter {
                parameters[ScreenViewParameter.hash.rawValue] = hash
            }
        }

        logEvent(event, parameters: parameters)
    }
}

private struct AnalyticsEvent: LoggableEvent {
    let name: String
}

public enum ScreenViewEventName: String, LoggableEvent {
    case screenView
    case screenViewError
}

public enum ScreenClass: String {
    case modal
    case splashFragment = "splashfragment"
    case errorScreen = "errorscreen"
    case uiController = "uicontroller"
    case webView = "webview"
}

enum ScreenViewParameter: String {
    case screenName = "screen_name"
    case screenClass = "screen_class"
    case screenID = "screen_id"
    case savedDocType = "saved_doc_type"
    case isError = "is_error"
    case reason
    case endpoint
    case status
    case hash
}

private extension String {
    var formattedAsAnalyticsParameter: String {
        prefix(100).lowercased()
    }
}

public struct AnalyticsData: Sendable {
    public let key: String
    public let value: any Sendable
}

extension AnalyticsData {
    static let savedDocType = AnalyticsData(key: "saved_doc_type", value: "undefined")
    static let publishingOrg = AnalyticsData(
        key: "primary_publishing_organisation",
        value: "government digital service - digital identity")
    static let organisation = AnalyticsData(key: "organisation", value: "<OT1056>")
    static let taxonomyLevel1 = AnalyticsData(key: "taxonomy_level1", value: "one login mobile application")
    static let taxonomyLevel2 = AnalyticsData(key: "taxonomy_level2", value: "wallet")
    static let taxonomyLevel3 = AnalyticsData(key: "taxonomy_level3", value: "proximity sharing")
    static let language = AnalyticsData(key: "language", value: NSLocale.current.identifier)

    static let screenViewDefaults: [AnalyticsData] = [
        savedDocType,
        publishingOrg,
        organisation,
        taxonomyLevel1,
        taxonomyLevel2,
        taxonomyLevel3,
        language
    ]
}

extension AnalyticsData {
    static let screenViewDefaultsDictionary: [String: any Sendable] = screenViewDefaults.reduce(into: [:]) { result, analyticsData in
        result[analyticsData.key] = analyticsData.value
    }
}
