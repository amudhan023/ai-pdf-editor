import CPDFium
import Foundation
import PDFEngineAPI

/// Bridges PDFium's context-free `FPDF_FILEWRITE` callback (`fpdf_save.h`)
/// to a Swift buffer. The C struct has no user-data field, so this widens
/// it: `base` occupies the same leading bytes PDFium's `FPDF_SaveAsCopy`
/// itself declares and dereferences (`version`, `WriteBlock`) and
/// `bufferRef` is appended after — safe because PDFium never reads past its
/// own struct's declared size, only ever treating the pointer it was given
/// as `FPDF_FILEWRITE*`. The trampoline below recovers `bufferRef` via
/// `withMemoryRebound`, the standard technique for widening a context-free
/// C callback struct.
private struct PDFiumSaveContext {
    var base: FPDF_FILEWRITE
    var bufferRef: Unmanaged<PDFiumSaveBuffer>
}

private final class PDFiumSaveBuffer {
    private(set) var data = Data()

    func append(_ pointer: UnsafeRawPointer, count: Int) {
        data.append(pointer.assumingMemoryBound(to: UInt8.self), count: count)
    }
}

private func pdfiumSaveWriteBlock(
    _ writer: UnsafeMutablePointer<FPDF_FILEWRITE>?,
    _ data: UnsafeRawPointer?,
    _ size: UInt
) -> Int32 {
    guard let writer, let data, size > 0 else { return 1 }
    return writer.withMemoryRebound(to: PDFiumSaveContext.self, capacity: 1) { context in
        context.pointee.bufferRef.takeUnretainedValue().append(data, count: Int(size))
        return 1
    }
}

/// Runs `FPDF_SaveAsCopy` for `document` with `flags` and returns the
/// serialized bytes. Save failures aren't among `mapPDFiumError()`'s
/// load-error codes (those map `FPDF_GetLastError()` for open/parse
/// failures), so this is its own typed `.ioFailure` path rather than
/// reusing that mapping incorrectly.
func pdfiumSaveAsCopy(_ document: FPDF_DOCUMENT, flags: FPDF_DWORD) throws -> Data {
    let buffer = PDFiumSaveBuffer()
    var context = PDFiumSaveContext(
        base: FPDF_FILEWRITE(version: 1, WriteBlock: pdfiumSaveWriteBlock),
        bufferRef: .passUnretained(buffer)
    )

    let succeeded = withUnsafeMutablePointer(to: &context) { contextPointer -> Bool in
        contextPointer.withMemoryRebound(to: FPDF_FILEWRITE.self, capacity: 1) { basePointer in
            FPDF_SaveAsCopy(document, basePointer, flags) != 0
        }
    }
    guard succeeded else {
        throw PDFEngineError.ioFailure("PDFium: FPDF_SaveAsCopy failed (FPDF_GetLastError=\(FPDF_GetLastError()))")
    }
    return buffer.data
}
