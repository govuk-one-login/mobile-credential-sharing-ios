@testable import SharingOrchestration
import Testing

@MainActor
@Suite("InactivityTimer Tests")
struct InactivityTimerTests {

    @Test("Timer fires after configured duration")
    func timerFiresAfterDuration() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.05) {
            didFire = true
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(80))

        // Then
        #expect(didFire == true)
    }

    @Test("Timer does not fire before duration elapses")
    func timerDoesNotFireEarly() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(30))

        // Then
        #expect(didFire == false)
        sut.stop()
    }

    @Test("Reset restarts the countdown")
    func resetRestartsCountdown() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.15) {
            didFire = true
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(100))
        sut.reset()
        try? await Task.sleep(for: .milliseconds(100))

        // Then — timer should not have fired yet (reset extended the window)
        #expect(didFire == false)

        // Wait for the full duration after reset
        try? await Task.sleep(for: .milliseconds(80))
        #expect(didFire == true)
    }

    @Test("Stop prevents the timer from firing")
    func stopPreventsTimerFromFiring() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.05) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        try? await Task.sleep(for: .milliseconds(80))

        // Then
        #expect(didFire == false)
    }

    @Test("Multiple resets only fire once after final reset")
    func multipleResetsOnlyFireOnce() async {
        // Given
        var fireCount = 0
        let sut = InactivityTimer(duration: 0.05) {
            fireCount += 1
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(20))
        sut.reset()
        try? await Task.sleep(for: .milliseconds(20))
        sut.reset()
        try? await Task.sleep(for: .milliseconds(80))

        // Then
        #expect(fireCount == 1)
    }

    @Test("Start after stop begins a new countdown")
    func startAfterStopBeginsNewCountdown() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.05) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        try? await Task.sleep(for: .milliseconds(80))
        #expect(didFire == false)

        sut.start()
        try? await Task.sleep(for: .milliseconds(80))

        // Then
        #expect(didFire == true)
    }

    @Test("Default timeout is 300 seconds")
    func defaultTimeoutValue() {
        #expect(InactivityTimer.defaultTimeout == 300)
    }

    @Test("Reset is a no-op when the timer is not running")
    func resetIsNoOpWhenNotRunning() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.05) {
            didFire = true
        }

        // When — reset without start
        sut.reset()
        try? await Task.sleep(for: .milliseconds(80))

        // Then — timer should not have fired
        #expect(didFire == false)
    }

    @Test("Reset is a no-op after stop")
    func resetIsNoOpAfterStop() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.05) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        sut.reset()
        try? await Task.sleep(for: .milliseconds(80))

        // Then — timer should not have restarted
        #expect(didFire == false)
    }
}
