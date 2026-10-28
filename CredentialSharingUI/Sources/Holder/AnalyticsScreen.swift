import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`).
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    case getReadyToShare = "GET_READY_TO_SHARE"
    case moreAboutDVS = "MORE_ABOUT_DVS"

    var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .moreAboutDVS:
            "288470f5-8bdb-43cf-8cd7-38bcd241413b"
        }
    }
}
