import Foundation

/// Abstracts `NSFileCoordinator` so `AtomicSaver` can inject a `Mock*` in
/// tests (CLAUDE.md §5 naming) without depending on real file-coordination
/// side effects. Production always uses `NSFileCoordinatorAdapter`.
public protocol FileCoordinating: Sendable {
    /// Runs `body` inside a coordinated write to `url` (`.forReplacing`):
    /// the correct intent for an atomic-replace save, since it tells
    /// coordination clients (notably iCloud Drive) that `url`'s contents
    /// are about to be wholesale swapped, not incrementally edited.
    /// `body` receives the URL coordination says to actually write to,
    /// which callers must use instead of the original `url` argument.
    func coordinateReplace(of url: URL, using body: (URL) throws -> Void) throws
}

/// Real implementation backed by `NSFileCoordinator`. Safe to use for
/// plain local files too — coordination is a no-op-ish pass-through when
/// there's no other file presenter registered for the URL, so this stays
/// the unconditional default rather than an iCloud-only special case.
public struct NSFileCoordinatorAdapter: FileCoordinating {
    public init() {}

    public func coordinateReplace(of url: URL, using body: (URL) throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var thrown: Error?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                try body(coordinatedURL)
            } catch {
                thrown = error
            }
        }

        if let coordinationError {
            throw AtomicSaveError.ioError("file coordination failed: \(coordinationError)")
        }
        if let thrown {
            throw thrown
        }
    }
}
