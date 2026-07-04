import Foundation

/// How a save is written back to disk. `incremental` appends a new xref
/// section (fast, safe for large documents); `fullRewrite` regenerates the
/// whole file (smaller output, required after heavy structural edits).
/// DocumentSession's atomic-save path (root CLAUDE.md §3.5) wraps whichever
/// mode the engine is asked to use — this enum doesn't itself imply atomicity.
public enum SaveMode: Sendable, Codable, Equatable {
    case incremental
    case fullRewrite
}

/// Engine-neutral document open/save/close. This is the minimal plumbing
/// needed to obtain a `DocumentHandle` in the first place and to persist
/// changes made through the other protocols in this package.
public protocol DocumentLifecycle: Sendable {
    func open(url: URL) async throws -> DocumentHandle
    func save(_ document: DocumentHandle, mode: SaveMode, to url: URL) async throws
    func close(_ document: DocumentHandle) async throws
}
