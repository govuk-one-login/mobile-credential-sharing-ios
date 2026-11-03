import GDSAnalytics

/// Holder sharing journey screens for GA4 analytics.
///
/// The `rawValue` is the screen's taxonomy name; `id` is the Firebase screen
/// identifier (`firebaseScreenID`).
enum AnalyticsScreen: String, ScreenType, Identifiable, CaseIterable {
    case getReadyToShare = "GET_READY_TO_SHARE"
    case gettingListOfDetails = "GETTING_LIST_OF_DETAILS"
    case sharingYourDetails = "SHARING_YOUR_DETAILS"

    var id: String {
        switch self {
        case .getReadyToShare:
            "3f5c1d0b-8068-4e19-8300-37f7bb468ff5"
        case .gettingListOfDetails:
            "06328966-cd42-49c4-a573-9140ace45297"
        case .sharingYourDetails:
            "aedea082-0575-4f4e-babf-b2221d74756f"
        }
    }
}
