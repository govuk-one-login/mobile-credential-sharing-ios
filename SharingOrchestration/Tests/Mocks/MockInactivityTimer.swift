@testable import SharingOrchestration

@MainActor
class MockInactivityTimer: InactivityTimerProtocol {
    var didCallStart = false
    var didCallReset = false
    var didCallStop = false
    var startCount = 0
    var resetCount = 0
    var stopCount = 0

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
}
