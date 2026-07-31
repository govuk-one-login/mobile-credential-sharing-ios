@testable import SharingOrchestration
import Testing

@MainActor
@Suite("InactivityTimer Tests")
struct InactivityTimerTests {

    @Test("Timer fires after configured duration")
    func timerFiresAfterDuration() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then
        #expect(didFire == true)
    }

    @Test("Timer does not fire before duration elapses")
    func timerDoesNotFireEarly() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.2) {
            didFire = true
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(didFire == false)
        sut.stop()
    }

    @Test("Reset restarts the countdown")
    func resetRestartsCountdown() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.2) {
            didFire = true
        }

        // When — start, wait 150ms (under 200ms), reset
        sut.start()
        try? await Task.sleep(for: .milliseconds(150))
        sut.reset()

        // Wait 150ms after reset — still under the 200ms duration
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then — timer should not have fired yet (reset extended the window)
        #expect(didFire == false)

        // Wait past the full duration after reset
        try? await Task.sleep(for: .milliseconds(100))
        await Task.yield()
        #expect(didFire == true)
    }

    @Test("Stop prevents the timer from firing")
    func stopPreventsTimerFromFiring() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then
        #expect(didFire == false)
    }

    @Test("Multiple resets only fire once after final reset")
    func multipleResetsOnlyFireOnce() async {
        // Given
        var fireCount = 0
        let sut = InactivityTimer(duration: 0.1) {
            fireCount += 1
        }

        // When
        sut.start()
        try? await Task.sleep(for: .milliseconds(50))
        sut.reset()
        try? await Task.sleep(for: .milliseconds(50))
        sut.reset()

        // Wait for the timer to fire after the final reset
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then
        #expect(fireCount == 1)
    }

    @Test("Start after stop begins a new countdown")
    func startAfterStopBeginsNewCountdown() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()
        #expect(didFire == false)

        sut.start()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

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
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When — reset without start
        sut.reset()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then — timer should not have fired
        #expect(didFire == false)
    }

    @Test("Reset is a no-op after stop")
    func resetIsNoOpAfterStop() async {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        sut.reset()
        try? await Task.sleep(for: .milliseconds(150))
        await Task.yield()

        // Then — timer should not have restarted
        #expect(didFire == false)
    }

    @Test("Stop before start does nothing")
    func stopBeforeStartDoesNothing() {
        // Given
        var didFire = false
        let sut = InactivityTimer(duration: 0.1) {
            didFire = true
        }

        // When
        sut.stop()

        // Then
        #expect(didFire == false)
    }
}
