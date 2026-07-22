import CPDFium
import Foundation
import PDFEngineAPI

/// `PDFiumEngine: PageOrganizer` (P1-06) — structural page-tree mutation via
/// `fpdf_edit.h`/`fpdf_ppo.h`. `PageOperation` (frozen, `PageOrganizer.swift`)
/// has exactly four cases; every other page operation the product needs
/// (duplicate, extract, split, merge) is a composition of these at the
/// `DocumentSession` layer — `.insert`'s `from` can name a different
/// document (cross-document import/merge) or the same one (duplicate), and
/// "extract"/"split" are "open a blank destination, insert the wanted pages
/// into it." No frozen-seam gap found; nothing here needed a `PageOrganizer`
/// change.
///
/// **Self-duplicate crash workaround:** `.insert` with `source == document`
/// (same-document duplicate) cannot call `FPDF_ImportPagesByIndex` with
/// `src_doc == dest_doc` — this vendored PDFium build crashes inside that
/// call for same-pointer src/dest, confirmed empirically via the
/// property-based fuzz test in `PDFiumPageOrganizerTests`, not assumed from
/// the (silent-on-this-point) header doc comment. Worked around by
/// importing from an independent in-memory snapshot instead; see the
/// `.insert` case below.
///
/// **Corruption-safety invariant (root CLAUDE.md driver 5):** `OpenDocument.pages`
/// caches loaded `FPDF_PAGE` handles by *index*. Any structural mutation
/// (insert/delete/reorder) invalidates that index -> handle mapping for
/// every cached page, not just the ones the operation directly touched — a
/// stale cached handle read after a structural mutation could silently
/// return the *wrong* page's content. `invalidatePageCache` closes and
/// clears the whole cache before any structural op; `.rotate` alone doesn't
/// call it (rotation changes a page's property, not the tree shape, and the
/// existing handle for that index is still the same page).
extension PDFiumEngine: PageOrganizer {
    public func apply(_ operation: PageOperation, to document: DocumentHandle) async throws {
        let entry = try requireDocument(document)

        switch operation {
        case .insert(let source, let sourcePage, let at):
            let sourceEntry = try requireDocument(source)
            let sourceCount = Int(FPDF_GetPageCount(sourceEntry.doc))
            guard sourcePage.value >= 0, sourcePage.value < sourceCount else {
                throw PDFEngineError.pageIndexOutOfRange(index: sourcePage.value, pageCount: sourceCount)
            }
            let destCount = Int(FPDF_GetPageCount(entry.doc))
            let insertAt = min(max(0, at.value), destCount)

            invalidatePageCache(document)
            var index = Int32(sourcePage.value)

            if source == document {
                // Empirically confirmed (not assumed from the header, whose
                // doc comment doesn't call this out either way): this
                // vendored PDFium build crashes inside FPDF_ImportPagesByIndex
                // when src_doc and dest_doc are the *same* pointer (the
                // self-duplicate case) — reproduced via the property-based
                // fuzz test below. Work around it by importing from an
                // independent in-memory snapshot of the same bytes instead,
                // so PDFium never sees src_doc == dest_doc. The snapshot's
                // backing Data must outlive the snapshot document per
                // fpdfview.h's FPDF_LoadMemDocument64 doc comment ("must
                // remain valid when the document is open").
                let snapshotData = try pdfiumSaveAsCopy(entry.doc, flags: FPDF_DWORD(FPDF_NO_INCREMENTAL))
                let ok: Int32 = snapshotData.withUnsafeBytes { rawBuffer in
                    guard let snapshotDoc = FPDF_LoadMemDocument64(rawBuffer.baseAddress, rawBuffer.count, nil) else {
                        return 0
                    }
                    defer { FPDF_CloseDocument(snapshotDoc) }
                    return withUnsafePointer(to: &index) { pointer in
                        FPDF_ImportPagesByIndex(entry.doc, snapshotDoc, pointer, 1, Int32(insertAt))
                    }
                }
                guard ok != 0 else { throw mapPDFiumError() }
            } else {
                let ok = withUnsafePointer(to: &index) { pointer in
                    FPDF_ImportPagesByIndex(entry.doc, sourceEntry.doc, pointer, 1, Int32(insertAt))
                }
                guard ok != 0 else { throw mapPDFiumError() }
            }

        case .delete(let page):
            let count = Int(FPDF_GetPageCount(entry.doc))
            guard page.value >= 0, page.value < count else {
                throw PDFEngineError.pageIndexOutOfRange(index: page.value, pageCount: count)
            }
            guard count > 1 else {
                throw PDFEngineError.unsupportedFeature("cannotDeleteOnlyRemainingPage")
            }
            invalidatePageCache(document)
            FPDFPage_Delete(entry.doc, Int32(page.value))

        case .reorder(let from, let to):
            let count = Int(FPDF_GetPageCount(entry.doc))
            guard from.value >= 0, from.value < count else {
                throw PDFEngineError.pageIndexOutOfRange(index: from.value, pageCount: count)
            }
            // FPDF_MovePages' dest index is relative to the array *after*
            // the moved pages are removed (verified against fpdf_edit.h's
            // own worked example) — same convention FakePDFEngine's
            // remove-then-insert implementation already uses, so this
            // matches the frozen protocol's one existing reference
            // implementation exactly.
            let insertAt = min(max(0, to.value), count - 1)
            invalidatePageCache(document)
            var index = Int32(from.value)
            let ok = withUnsafePointer(to: &index) { pointer in
                FPDF_MovePages(entry.doc, pointer, 1, Int32(insertAt))
            }
            guard ok != 0 else { throw mapPDFiumError() }

        case .rotate(let page, let rotation):
            let pageHandle = try loadedPage(document, index: page.value)
            FPDFPage_SetRotation(pageHandle, Int32(rotation.rawValue / 90))
        }
    }
}
