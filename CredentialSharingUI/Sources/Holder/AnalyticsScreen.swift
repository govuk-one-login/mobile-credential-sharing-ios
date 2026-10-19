import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`).
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    /// "Get ready to share" (readiness / preflight) screen.
    case readiness = "READINESS"

    var id: String {
        switch self {
        case .readiness:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        }
    }
}
