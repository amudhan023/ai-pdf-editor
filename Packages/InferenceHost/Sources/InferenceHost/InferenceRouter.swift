import Foundation
import InferenceAPI

/// Priority-queue request router (ARCHITECTURE.md §7.2): interactive
/// requests preempt a running background operation. Preemption is
/// cooperative Task cancellation, not preallocated queueing — a background
/// operation's closure must itself observe `Task.checkCancellation()` at
/// safe points; if it does, the caller sees `InferenceError.requestCancelled`
/// and is expected to resubmit (background inference calls are idempotent,
/// so an automatic retry here would be safe too, but retry policy is left
/// to the caller per CLAUDE.md §15's "automatic retry only where
/// idempotent" — this layer only guarantees the interactive request isn't
/// blocked behind the background one).
///
/// Being an actor, calls into `runInteractive`/`runBackground` interleave
/// at their internal `await` points — that's what lets an interactive call
/// arriving while a background call is suspended on `task.value` reach
/// `preemptRunningBackground()` and cancel it before the background
/// operation completes.
public actor InferenceRouter {
    private var cancelRunningBackground: (() -> Void)?

    public init() {}

    public func runInteractive<T: Sendable>(
        _ operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        cancelRunningBackground?()
        return try await operation()
    }

    public func runBackground<T: Sendable>(
        _ operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        let task = Task<T, Error> { try await operation() }
        cancelRunningBackground = { task.cancel() }
        defer { cancelRunningBackground = nil }
        do {
            return try await task.value
        } catch is CancellationError {
            throw InferenceError.requestCancelled
        }
    }
}
