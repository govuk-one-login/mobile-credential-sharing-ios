@testable import SharingOrchestration

@MainActor
class MockInactivityTimer: InactivityTimerProtocol {
    var didCallStart = false
    var didCallReset = false
    var didCallStop = false
    var startCount = 0
    var resetCount = 0
    var stopCount = 0
    
    /// Closure to simulate the timer firing — call this in tests to trigger timeout.
    var onTimeout: (@MainActor () -> Void)?
    
    func start() {
        didCallStart = true
        startCount += 1
    }
    
    func reset() {
        didCallReset = true
        resetCount += 1
    }
    
    func stop() {
        didCallStop = true
        stopCount += 1
    }
    
    /// Simulates the timer firing by invoking the timeout handler.
    func simulateTimeout() {
        onTimeout?()
    }
}
