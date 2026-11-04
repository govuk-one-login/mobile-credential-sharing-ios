import GDSAnalytics

public protocol SharingAnalyticsService {
    func logEvent(_ event: Event)
    func logCrash(_ crash: Error)

    func trackScreen<T: CustomStringConvertible>(_ screen: ScreenView<T>)
    func trackScreen<T: CustomStringConvertible>(_ screen: ErrorScreenView<T>)

    func addingAdditionalParameters(_ additionalParameters: [String: Any]) -> Self
}
