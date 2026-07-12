import CPDFium

/// P0-03 linkage proof: calls into the real vendored PDFium binary (not a
/// fake) to confirm the xcframework actually links and its symbols resolve
/// at runtime — see `docs/adr/ADR-001-pdfium-source-and-pin.md`. No PDF
/// parsing/rendering logic lives here yet; that's later Track A tasks.
public enum DocEngineHostModule {
    public static let name = "DocEngineHost"

    /// Initializes and immediately tears down the PDFium library, returning
    /// the last-error code PDFium reports (0 == `FPDF_ERR_SUCCESS`) as
    /// evidence the call actually reached the real library.
    public static func pdfiumLinkageCheck() -> UInt {
        FPDF_InitLibrary()
        defer { FPDF_DestroyLibrary() }
        return FPDF_GetLastError()
    }
}
