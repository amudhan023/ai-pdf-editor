import Foundation
import PDFEngineAPI

/// Typed failure taxonomy for the save path (CLAUDE.md §15 shape).
/// `validationFailed` means `original` was never touched — the caller's
/// temp file and prior document state are both still exactly as they were.
public enum AtomicSaveError: Error, Sendable, Equatable {
    case validationFailed(reason: String)
    case ioError(String)
}

/// The never-corrupt save path (P1-16, ARCHITECTURE.md §8.4, root CLAUDE.md
/// driver 5): write-to-temp (caller's job) -> validate by reopening through
/// the engine -> atomic replace -> versioned backup.
///
/// Atomicity comes from `FileManager.replaceItemAt`, the one macOS primitive
/// that swaps `original`'s contents for `temp`'s and captures `original`'s
/// prior bytes as a same-directory backup file in a single call — there is
/// no observable window where `original` is missing or partially written,
/// even across a crash mid-call (the filesystem either completes the
/// replace or leaves the original file untouched). A validation failure
/// throws before this call happens at all, so `original` is provably
/// unmodified in that path too.
///
/// The versioned backup is captured *before* the swap by copying
/// `original` into `backupDirectory` — not via `replaceItemAt`'s own
/// `backupItemName` parameter, which (verified empirically on this
/// toolchain: same-volume swaps skip creating the backup file entirely,
/// undocumented but reproducible) cannot be relied on. If that pre-swap
/// copy fails, `replace` throws before `original` is touched at all; a
/// crash or failure any time after the copy still leaves `original`
/// governed solely by `replaceItemAt`'s own atomicity guarantee.
public struct AtomicSaver: Sendable {
    private let engine: DocumentLifecycle
    private let backupDirectory: URL
    private let retentionCount: Int

    public init(engine: DocumentLifecycle, backupDirectory: URL, retentionCount: Int = 10) {
        self.engine = engine
        self.backupDirectory = backupDirectory
        self.retentionCount = retentionCount
    }

    /// Replaces `original`'s contents with `temp`'s. Safe to call
    /// repeatedly against the same `original` — each call adds a new
    /// versioned backup rather than colliding on a fixed name.
    @discardableResult
    public func replace(original: URL, withTemp temp: URL, now: Date = Date()) async throws -> URL {
        try await validate(temp)

        if FileManager.default.fileExists(atPath: original.path) {
            try captureVersionedBackup(of: original, now: now)
        }

        do {
            return try FileManager.default.replaceItemAt(
                original,
                withItemAt: temp,
                backupItemName: nil
            ) ?? original
        } catch {
            throw AtomicSaveError.ioError("\(error)")
        }
    }

    /// Reopens `temp` through the engine as a structural check before
    /// anything touches `original` — per the task's "validation step =
    /// reopen + structural check before replace," not a whole-file load.
    private func validate(_ temp: URL) async throws {
        let handle: DocumentHandle
        do {
            handle = try await engine.open(url: temp)
        } catch {
            throw AtomicSaveError.validationFailed(reason: "\(error)")
        }
        try? await engine.close(handle)
    }

    /// Copies `original`'s current bytes into a fresh, uniquely-named entry
    /// in `backupDirectory`, then prunes down to `retentionCount`. Runs
    /// before the atomic swap, so `original` itself is never a party to
    /// this step's failure modes.
    private func captureVersionedBackup(of original: URL, now: Date) throws {
        do {
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let stem = original.deletingPathExtension().lastPathComponent
            let timestamp = Self.timestampFormatter.string(from: now)
            let disambiguator = UUID().uuidString.prefix(8)
            let versionedName = "\(stem)-\(timestamp)-\(disambiguator).\(original.pathExtension).backup"
            let destination = backupDirectory.appendingPathComponent(versionedName)
            try FileManager.default.copyItem(at: original, to: destination)
        } catch {
            throw AtomicSaveError.ioError("failed to capture versioned backup: \(error)")
        }
        pruneOldBackups(for: original)
    }

    private func pruneOldBackups(for original: URL) {
        let prefix = original.deletingPathExtension().lastPathComponent + "-"
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let matching = entries.filter { $0.lastPathComponent.hasPrefix(prefix) }
        let ordered = matching.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
        for stale in ordered.dropFirst(retentionCount) {
            try? FileManager.default.removeItem(at: stale)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
