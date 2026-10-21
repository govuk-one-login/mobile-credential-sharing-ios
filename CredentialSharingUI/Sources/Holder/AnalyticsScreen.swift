import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier. Mirrors the host application's `AnalyticsScreen` pattern.
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    /// "Details shared" screen.
    case detailsShared = "DETAILS_SHARED"

    var id: String {
        switch self {
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        }
    }
}
