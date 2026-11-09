import Foundation
import GDSAnalytics
@testable import mobile_credential_sharing_ios
import Testing

@Suite("ScreenView+Loggable Tests")
struct ScreenViewLoggableTests {

    @Test("ScreenView.name returns the screen view's title")
    func screenViewNameIsTitle() {
        let screenView = ScreenView(
            screen: MockLoggableScreenType.test,
            titleKey: "A plain title"
        )

        // LoggableScreen.name is the resolved (English) title.
        #expect(screenView.name == screenView.title)
    }

    @Test("ScreenView.type returns the underlying screen")
    func screenViewTypeIsScreen() {
        let screenView = ScreenView(
            screen: MockLoggableScreenType.test,
            titleKey: "A plain title"
        )

        #expect(screenView.type == .test)
    }

    @Test("ErrorScreenView.name returns the error screen view's title")
    func errorScreenViewNameIsTitle() {
        let errorScreenView = ErrorScreenView(
            screen: MockLoggableScreenType.test,
            titleKey: "An error title"
        )

        #expect(errorScreenView.name == errorScreenView.title)
    }

    @Test("ErrorScreenView.type returns the underlying screen")
    func errorScreenViewTypeIsScreen() {
        let errorScreenView = ErrorScreenView(
            screen: MockLoggableScreenType.test,
            titleKey: "An error title"
        )

        #expect(errorScreenView.type == .test)
    }
}

// MARK: - Mocks

private enum MockLoggableScreenType: String, ScreenType {
    case test = "TEST_SCREEN"
}
