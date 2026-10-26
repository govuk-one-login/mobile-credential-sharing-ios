import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`). Mirrors the host application's
/// `AnalyticsScreen` pattern.
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    case getReadyToShare = "GET_READY_TO_SHARE"

    /// "Details shared" screen.
    case detailsShared = "DETAILS_SHARED"

    var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .detailsShared:
            "c2ccd487-c0e0-4ef8-943b-c555c4856a2c"
        }
    }
}
