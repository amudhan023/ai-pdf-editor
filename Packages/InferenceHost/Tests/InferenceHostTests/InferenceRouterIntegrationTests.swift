import XCTest
import InferenceAPI
@testable import InferenceHost

/// Named `*IntegrationTests` per CLAUDE.md §9 / P0-15 so
/// `Scripts/verify-integration.sh InferenceHost` picks this up
/// automatically. Exercises this task's second acceptance criterion:
/// "Interactive request preempts a running background batch."
private actor IterationCounter {
    private(set) var value = 0
    func set(_ newValue: Int) { value = newValue }
}

final class InferenceRouterIntegrationTests: XCTestCase {
    func testInteractiveRequestPreemptsRunningBackgroundOperation() async throws {
        let router = InferenceRouter()
        let progress = IterationCounter()

        let backgroundTask = Task {
            try await router.runBackground {
                for iteration in 1...20 {
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: 20_000_000) // 20ms
                    await progress.set(iteration)
                }
                return "background-finished"
            }
        }

        // Give the background op a moment to start running before preempting it.
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms

        let interactiveResult = try await router.runInteractive {
            "interactive-result"
        }
        XCTAssertEqual(interactiveResult, "interactive-result")

        do {
            _ = try await backgroundTask.value
            XCTFail("expected the background operation to be cancelled by the interactive preemption")
        } catch InferenceError.requestCancelled {
            // expected: preempted, caller is responsible for resubmitting
        }

        let completed = await progress.value
        XCTAssertLessThan(
            completed, 20,
            "background operation should have been cancelled before running to completion"
        )
    }

    func testBackgroundOperationCompletesWhenNotPreempted() async throws {
        let router = InferenceRouter()
        let result = try await router.runBackground {
            try await Task.sleep(nanoseconds: 10_000_000)
            return "done"
        }
        XCTAssertEqual(result, "done")
    }
}
