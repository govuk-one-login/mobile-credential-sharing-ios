import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier. Mirrors the host application's `AnalyticsScreen` pattern.
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    /// "Get ready to share" (readiness / preflight) screen.
    case readiness = "READINESS"
    /// "Details shared" screen.
    case detailsShared = "DETAILS_SHARED"

    var id: String {
        switch self {
        case .readiness:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        }
    }
}
