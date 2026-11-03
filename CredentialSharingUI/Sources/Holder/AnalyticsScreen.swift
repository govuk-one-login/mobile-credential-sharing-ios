import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`).
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    case getReadyToShare = "GET_READY_TO_SHARE"
    case consent = "CONSENT"

    var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .consent:
            "ac1f2e03-2b4e-4804-8c16-2d18c37b0f9e"
        }
    }
}
