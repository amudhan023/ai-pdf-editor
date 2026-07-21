import CPDFium
import Foundation

/// A no-op `FPDF_FORMFILLINFO` (P2-01). `FPDFDOC_InitFormFillEnvironment`
/// requires a fully-populated callback struct — PDFium's internals call
/// several of these fields unconditionally during field access, so every
/// field must be a valid (if trivial) function pointer, not left null. We
/// only need field introspection/value read-write (`FPDFAnnot_GetFormField*`,
/// `FPDFAnnot_SetFormFieldValue`-family calls), never real interactive
/// rendering/timers/popups/network — so every callback here is an inert
/// stub returning a safe default. `xfa_disabled = 1` since this vendored
/// build has no XFA module (`DocEngineHost/CLAUDE.md`: `pdf_enable_v8=false`
/// - XFA needs V8). C function pointers can't capture state, hence free
/// closures rather than methods.
enum FormFillEnvironment {
    static func makeHandle(for document: OpaquePointer) -> FPDF_FORMHANDLE? {
        withUnsafeMutablePointer(to: &sharedInfo) { pointer in
            FPDFDOC_InitFormFillEnvironment(document, pointer)
        }
    }

    static func closeHandle(_ handle: FPDF_FORMHANDLE) {
        FPDFDOC_ExitFormFillEnvironment(handle)
    }
}

/// Process-wide, written once at first use, never mutated afterward — same
/// one-time-init shape as `PDFiumEngine.pdfiumLibraryInitialized`, but this
/// needs a stable `var` (not `let`) because `FPDFDOC_InitFormFillEnvironment`
/// takes an `UnsafeMutablePointer`; `nonisolated(unsafe)` documents that this
/// is safe by construction (content is fixed after the lazy initializer
/// runs), same as any C-interop global buffer.
private nonisolated(unsafe) var sharedInfo: FPDF_FORMFILLINFO = {
    var info = FPDF_FORMFILLINFO()
    info.version = 1
    info.xfa_disabled = 1
    info.Release = { _ in }
    info.FFI_Invalidate = { _, _, _, _, _, _ in }
    info.FFI_OutputSelectedRect = { _, _, _, _, _, _ in }
    info.FFI_SetCursor = { _, _ in }
    info.FFI_SetTimer = { _, _, _ in 0 }
    info.FFI_KillTimer = { _, _ in }
    info.FFI_GetLocalTime = { _ in FPDF_SYSTEMTIME() }
    info.FFI_OnChange = { _ in }
    info.FFI_GetPage = { _, _, _ in nil }
    info.FFI_GetCurrentPage = { _, _ in nil }
    info.FFI_GetRotation = { _, _ in 0 }
    info.FFI_ExecuteNamedAction = { _, _ in }
    info.FFI_SetTextFieldFocus = { _, _, _, _ in }
    info.FFI_DoURIAction = { _, _ in }
    info.FFI_DoGoToAction = { _, _, _, _, _ in }
    info.FFI_DisplayCaret = { _, _, _, _, _, _, _ in }
    info.FFI_GetCurrentPageIndex = { _, _ in 0 }
    info.FFI_SetCurrentPage = { _, _, _ in }
    info.FFI_GotoURL = { _, _, _ in }
    info.FFI_GetPageViewRect = { _, _, left, top, right, bottom in
        left?.pointee = 0; top?.pointee = 0; right?.pointee = 0; bottom?.pointee = 0
    }
    info.FFI_PageEvent = { _, _, _ in }
    info.FFI_PopupMenu = { _, _, _, _, _, _ in 0 }
    info.FFI_OpenFile = { _, _, _, _ in nil }
    info.FFI_EmailTo = { _, _, _, _, _, _, _ in }
    info.FFI_UploadTo = { _, _, _, _ in }
    info.FFI_GetPlatform = { _, _, _ in 0 }
    info.FFI_GetLanguage = { _, _, _ in 0 }
    info.FFI_DownloadFromURL = { _, _ in nil }
    info.FFI_PostRequestURL = { _, _, _, _, _, _, _ in 0 }
    info.FFI_PutRequestURL = { _, _, _, _ in 0 }
    info.FFI_OnFocusChange = { _, _, _ in }
    info.FFI_DoURIActionWithKeyboardModifier = { _, _, _ in }
    return info
}()
