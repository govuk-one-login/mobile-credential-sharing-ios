import Foundation
import Logging
@testable import mobile_credential_sharing_ios
import Testing

@Suite("AnalyticsServiceProvider Tests")
struct AnalyticsServiceProviderTests {

    // MARK: makeAnalyticsService

    @Test("Returns DebugLoggingService when GoogleService-Info.plist is absent from the bundle")
    func returnsDebugLoggingServiceWhenPlistMissing() {
        // Given
        let bundle = Bundle(for: AnalyticsServiceProviderBundleToken.self)

        // When
        let service = AnalyticsServiceProvider.makeAnalyticsService(bundle: bundle)

        // Then
        #expect(service is DebugLoggingService)
    }
}

// MARK: - Mocks
private class AnalyticsServiceProviderBundleToken {}
