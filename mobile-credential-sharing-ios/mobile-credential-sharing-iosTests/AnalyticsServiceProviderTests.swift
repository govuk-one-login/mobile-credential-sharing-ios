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

// MARK: - TempPreferenceStore Tests
@Suite("TempPreferenceStore Tests")
struct TempPreferenceStoreTests {

    @Test("Defaults to having asked for and accepted analytics permissions")
    func defaultsToAccepted() {
        // Given
        let sut = TempPreferenceStore()

        // Then
        #expect(sut.hasAskedForAnalyticsPermissions == true)
        #expect(sut.hasAcceptedAnalytics == true)
    }

    @Test("stream does not throw")
    func streamDoesNotThrow() {
        // Given
        let sut = TempPreferenceStore()

        // Then
        #expect(throws: Never.self) {
            _ = sut.stream()
        }
    }
}

// MARK: - Mocks
private class AnalyticsServiceProviderBundleToken {}
