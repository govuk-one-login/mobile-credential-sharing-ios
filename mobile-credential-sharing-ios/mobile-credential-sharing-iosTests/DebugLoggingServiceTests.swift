import Logging
@testable import mobile_credential_sharing_ios
import XCTest

final class DebugLoggingServiceTests: XCTestCase {
    var sut: DebugLoggingService!
    var mockPreferenceStore: MockAnalyticsPreferenceStore!
    
    override func setUp() {
        super.setUp()
        mockPreferenceStore = MockAnalyticsPreferenceStore()
        sut = DebugLoggingService(analyticsPreferenceStore: mockPreferenceStore)
    }
    
    override func tearDown() {
        sut = nil
        mockPreferenceStore = nil
        super.tearDown()
    }
    
    func test_init_setsPreferenceStore() {
        XCTAssertTrue(sut.analyticsPreferenceStore is MockAnalyticsPreferenceStore)
    }
    
    func test_init_setsEmptyAdditionalParameters() {
        XCTAssertTrue(sut.additionalParameters.isEmpty)
    }
    
    func test_addingAdditionalParameters_mergesParameters() {
        sut.additionalParameters = ["key1": "value1"]
        
        _ = sut.addingAdditionalParameters(["key2": "value2"])
        
        XCTAssertEqual(sut.additionalParameters.count, 2)
        XCTAssertEqual(sut.additionalParameters["key1"] as? String, "value1")
        XCTAssertEqual(sut.additionalParameters["key2"] as? String, "value2")
    }
    
    func test_addingAdditionalParameters_prefersExistingValues() {
        sut.additionalParameters = ["key1": "existing"]
        
        _ = sut.addingAdditionalParameters(["key1": "new"])
        
        XCTAssertEqual(sut.additionalParameters["key1"] as? String, "existing")
    }
    
    func test_addingAdditionalParameters_returnsSelf() {
        let result = sut.addingAdditionalParameters(["key": "value"])
        
        XCTAssertTrue(result === sut)
    }
    
    func test_trackScreen_doesNotThrow() {
        let screen = MockScreen()
        
        XCTAssertNoThrow(sut.trackScreen(screen, parameters: ["param": "value"]))
    }
    
    func test_logEvent_doesNotThrow() {
        let event = MockEvent()
        
        XCTAssertNoThrow(sut.logEvent(event, parameters: ["param": "value"]))
    }
    
    func test_logCrashNSError_doesNotThrow() {
        let error = NSError(domain: "test", code: 1)
        
        XCTAssertNoThrow(sut.logCrash(error))
    }
    
    func test_logCrashError_doesNotThrow() {
        let error = MockError.testError
        
        XCTAssertNoThrow(sut.logCrash(error))
    }
}

// MARK: - Mocks
final class MockAnalyticsPreferenceStore: AnalyticsPreferenceStore {
    var hasAcceptedAnalytics: Bool?
    
    func stream() -> AsyncStream<Bool> {
        AsyncStream { _ in }
    }
}

struct MockScreen: LoggableScreen {
    var name: String { "MockScreen" }
    var type: MockScreenType { .test }
}

enum MockScreenType: CustomStringConvertible {
    case test
    
    var description: String { "test" }
}

struct MockEvent: LoggableEvent {
    var name: String { "MockEvent" }
}

enum MockError: Error {
    case testError
}
