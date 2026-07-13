import XCTest
@testable import Platform

private actor RecordingSubscriber: DomainEventSubscriber {
    private(set) var received: [DomainEvent] = []

    func handle(_ event: DomainEvent) async throws {
        received.append(event)
    }
}

private struct FailingSubscriber: DomainEventSubscriber {
    struct Failure: Error {}
    func handle(_ event: DomainEvent) async throws {
        throw Failure()
    }
}

final class DomainEventBusTests: XCTestCase {
    func testPublishDeliversToAllSubscribersInOrder() async throws {
        let bus = DomainEventBus()
        let first = RecordingSubscriber()
        let second = RecordingSubscriber()
        await bus.subscribe(first)
        await bus.subscribe(second)

        try await bus.publish(.vaultRead(fieldPath: "identity.name", ticketID: "t1"))
        try await bus.publish(.fillCommitted(fieldPath: "identity.dob", ticketID: "t2"))

        let firstReceived = await first.received
        let secondReceived = await second.received
        XCTAssertEqual(firstReceived, [
            .vaultRead(fieldPath: "identity.name", ticketID: "t1"),
            .fillCommitted(fieldPath: "identity.dob", ticketID: "t2")
        ])
        XCTAssertEqual(secondReceived, firstReceived)
    }

    /// `publish` awaits the subscriber before returning — this is the
    /// mechanism that gives a caller "committed only once durable" for
    /// whichever subscriber does the actual durable write.
    func testPublishPropagatesSubscriberFailure() async {
        let bus = DomainEventBus()
        await bus.subscribe(FailingSubscriber())

        do {
            try await bus.publish(.authEvent(ticketID: "t1"))
            XCTFail("expected publish to rethrow the subscriber's failure")
        } catch is FailingSubscriber.Failure {
            // expected
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
