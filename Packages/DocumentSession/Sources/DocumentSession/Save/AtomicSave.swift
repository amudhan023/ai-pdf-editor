import Foundation
import PDFEngineAPI
import Platform

public enum AtomicSaveError: Error {
    case validationFailed
    case ioError(Error)
}

public struct AtomicSaver {
    // Very small, deterministic atomic replace helper used by DocumentSession.
    // writeTemp -> validate (reopen) -> atomic replace (move).
    public init() {}

    public func replace(original: URL, withTemp temp: URL) throws {
        do {
            // validation step: ensure temp is readable and non-empty
            let data = try Data(contentsOf: temp)
            guard !data.isEmpty else { throw AtomicSaveError.validationFailed }

            // write to a safe location and atomically replace
            let backup = original.appendingPathExtension("backup")
            if FileManager.default.fileExists(atPath: original.path) {
                try FileManager.default.moveItem(at: original, to: backup)
            }
            try FileManager.default.moveItem(at: temp, to: original)
            // keep backup for now (rotation handled elsewhere)
        } catch let e as AtomicSaveError {
            throw e
        } catch {
            throw AtomicSaveError.ioError(error)
        }
    }
}
