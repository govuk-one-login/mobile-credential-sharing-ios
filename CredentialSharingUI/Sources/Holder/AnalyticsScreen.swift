import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`).
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    case getReadyToShare = "GET_READY_TO_SHARE"

    var id: String {
        switch self {
        case .getReadyToShare:
        }
    }
}
