import os

/// A manually-advanced clock for deterministic testing.
///
/// Conforms to `Clock` with `Duration == Swift.Duration`.
/// Time only moves forward when you call `advance(by:)`.
///
/// Because the `Clock` protocol's `sleep` method is non-isolated,
/// internal state is protected by an `OSAllocatedUnfairLock` (a lightweight
/// mutex from the `os` framework, available iOS 16+).
final class TestClock: Clock, Sendable {

    // MARK: - Subtypes

    struct Instant: InstantProtocol, Sendable {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Storage: Sendable {
        var now: Instant = Instant(offset: .zero)
        var sleepers: [Sleeper] = []
    }

    private struct Sleeper: Sendable {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Never>
    }

    // MARK: - Type Alias

    typealias Duration = Swift.Duration

    // MARK: - Instance Properties

    var now: Instant {
        storage.withLock { $0.now }
    }

    var minimumResolution: Duration { .zero }

    /// All mutable state lives behind this lock so `sleep` (non-isolated)
    /// and `advance` (@MainActor) can safely share it.
    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    // MARK: - Methods

    /// Moves the clock forward and resumes any sleepers whose deadline has passed.
    ///
    /// Call from your `@MainActor` test. After this returns, woken sleepers
    /// have been resumed but may not have executed yet — use `await tick()`
    /// to drain the executor before making assertions.
    @MainActor
    func advance(by duration: Duration) {
        let woken = storage.withLock { state -> [Sleeper] in
            state.now = state.now.advanced(by: duration)
            let ready = state.sleepers.filter { $0.deadline <= state.now }
            state.sleepers.removeAll { $0.deadline <= state.now }
            return ready
        }
        for sleeper in woken {
            sleeper.continuation.resume()
        }
    }

    /// Drains pending `@MainActor` work so that resumed tasks execute.
    ///
    /// Call after `start()` / `reset()` (to let the timer register its sleeper)
    /// and after `advance(by:)` (to let the woken timer run its callback).
    ///
    /// Internally yields execution multiple times by detaching low-priority tasks,
    /// ensuring that any higher-priority `@MainActor` work (such as resumed timer
    /// continuations) runs first. This follows the same pattern used by PointFree's
    /// `swift-clocks` library (`Task.megaYield`) which is the accepted community
    /// approach for reliable async test synchronization, by yielding 20 times.
    @MainActor
    func tick() async {
        for _ in 0..<20 {
            await Task<Void, Never>.detached(priority: .background) {
                await Task.yield()
            }.value
        }
    }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try Task.checkCancellation()

        let alreadyPassed = storage.withLock { $0.now >= deadline }
        if alreadyPassed { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storage.withLock { state in
                state.sleepers.append(Sleeper(deadline: deadline, continuation: continuation))
            }
        }
        try Task.checkCancellation()
    }
}
