@testable import SharingOrchestration
import Testing

@MainActor
@Suite("InactivityTimer Tests")
struct InactivityTimerTests {

    @Test("Timer fires after configured duration")
    func timerFiresAfterDuration() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.start()
        await clock.tick()        // let the timer task register its sleeper
        clock.advance(by: .seconds(5))
        await clock.tick()        // let the woken task run onTimeout

        // Then
        #expect(didFire == true)
    }

    @Test("Timer does not fire before duration elapses")
    func timerDoesNotFireEarly() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.start()
        await clock.tick()
        clock.advance(by: .seconds(4))
        await clock.tick()

        // Then
        #expect(didFire == false)
        sut.stop()
    }

    @Test("Reset restarts the countdown")
    func resetRestartsCountdown() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When — start, advance partway, reset
        sut.start()
        await clock.tick()
        clock.advance(by: .seconds(3))
        await clock.tick()
        sut.reset()
        await clock.tick()        // let the new timer task register

        // Advance 3s after reset — still under the 5s duration
        clock.advance(by: .seconds(3))
        await clock.tick()

        // Then — timer should not have fired yet (reset extended the window)
        #expect(didFire == false)

        // Advance past the full duration after reset
        clock.advance(by: .seconds(2))
        await clock.tick()
        #expect(didFire == true)
    }

    @Test("Stop prevents the timer from firing")
    func stopPreventsTimerFromFiring() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        clock.advance(by: .seconds(10))
        await clock.tick()

        // Then
        #expect(didFire == false)
    }

    @Test("Multiple resets only fire once after final reset")
    func multipleResetsOnlyFireOnce() async {
        // Given
        let clock = TestClock()
        var fireCount = 0
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            fireCount += 1
        }

        // When
        sut.start()
        await clock.tick()
        clock.advance(by: .seconds(2))
        await clock.tick()
        sut.reset()
        await clock.tick()
        clock.advance(by: .seconds(2))
        await clock.tick()
        sut.reset()
        await clock.tick()

        // Advance past the final reset's duration
        clock.advance(by: .seconds(5))
        await clock.tick()

        // Then
        #expect(fireCount == 1)
    }

    @Test("Start after stop begins a new countdown")
    func startAfterStopBeginsNewCountdown() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        clock.advance(by: .seconds(10))
        await clock.tick()
        #expect(didFire == false)

        sut.start()
        await clock.tick()
        clock.advance(by: .seconds(5))
        await clock.tick()

        // Then
        #expect(didFire == true)
    }

    @Test("Default timeout is 300 seconds")
    func defaultTimeoutValue() {
        let clock = TestClock()
        let timer = InactivityTimer(clock: clock) { }
        #expect(timer.duration == .seconds(300))
    }

    @Test("Reset is a no-op when the timer is not running")
    func resetIsNoOpWhenNotRunning() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When — reset without start
        sut.reset()
        clock.advance(by: .seconds(10))
        await clock.tick()

        // Then — timer should not have fired
        #expect(didFire == false)
    }

    @Test("Reset is a no-op after stop")
    func resetIsNoOpAfterStop() async {
        // Given
        let clock = TestClock()
        var didFire = false
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.start()
        sut.stop()
        sut.reset()
        clock.advance(by: .seconds(10))
        await clock.tick()

        // Then — timer should not have restarted
        #expect(didFire == false)
    }

    @Test("Stop before start does nothing")
    func stopBeforeStartDoesNothing() {
        // Given
        var didFire = false
        let clock = TestClock()
        let sut = InactivityTimer(duration: .seconds(5), clock: clock) {
            didFire = true
        }

        // When
        sut.stop()

        // Then
        #expect(didFire == false)
    }
}
