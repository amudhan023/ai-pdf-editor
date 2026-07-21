import CPDFium
import Foundation
import PDFEngineAPI

/// `PDFiumEngine: FormModel` (P2-01) — real AcroForm field-tree read/write
/// via `fpdf_annot.h`'s `FPDFAnnot_GetFormField*`/`Set*` family, which
/// requires an `FPDF_FORMHANDLE` from `FormFillEnvironment` (see that file).
/// Widget annotations (`FPDF_ANNOT_WIDGET`, `fpdf_annot.h`'s `#define
/// FPDF_ANNOT_WIDGET 20` — not in the `FPDFANNOT_SUBTYPE`-mirroring
/// `AnnotationSubtype` enum since widgets aren't markup annotations) *are*
/// form fields at PDFium's API level; there is no separate field-tree walk.
///
/// **Identity:** `FormField.id` is `name` (frozen, `FormModel.swift`), but
/// PDFium resolves every widget in a radio-button group to the *same*
/// fully-qualified field name (`FPDFAnnot_GetFormFieldName`) — one PDF field
/// object, many widget kids. Using the raw name as `id` would collide across
/// group siblings. Disambiguated via `FPDFAnnot_GetFormControlIndex`/`Count`
/// (a widget's position among its siblings under one field): when a field
/// has more than one control, `id`/`name` becomes `"<name>#<controlIndex>"`
/// and the original shared name moves to `groupName` (ADR-016); a
/// single-control field keeps its bare name and `groupName == nil`.
///
/// **Tab order:** the vendored PDFium build exposes no `/TabOrder` (or
/// equivalent) accessor. ISO 32000-1 §12.7.4.3's own fallback when a page
/// has no explicit `/Tabs` entry is annotation-array (document/encounter)
/// order — `tabOrder` here is exactly that encounter order, not a
/// workaround but the spec's own default.
///
/// **Write path — known incomplete (see task Journal's Handoff):**
/// `setValue` writes `/V` (and `/AS` for checkbox/radio, matching the
/// current or a newly-chosen export value) via `FPDFAnnot_SetStringValue`,
/// the same generic per-key setter `PDFiumAnnotationStore` already uses for
/// `/NM`/`/T`/`/Contents` — a real, spec-correct field-value write, not a
/// hack. What's *not* done: appearance-stream regeneration. This vendored
/// PDFium's public headers expose no direct "set value and regenerate
/// appearance" call for text fields (the interactive path is
/// `FORM_SetFocusedAnnot` + `FORM_ReplaceSelection`, which simulates
/// keystrokes into a focused widget — not attempted here) nor a checkbox/
/// radio "click" simulator. `setValue` does not currently also flip the
/// AcroForm `/NeedAppearances` flag (no accessor found for the AcroForm
/// dictionary itself in the vendored headers) — so a value written by this
/// code is logically correct and round-trips through this engine's own
/// `fields(of:)`, but is **not yet verified to render in Acrobat/Preview**
/// (the task's NFR-C2 acceptance criterion). Flagged, not silently claimed.
extension PDFiumEngine: FormModel {
    public func fields(of document: DocumentHandle) async throws -> [FormField] {
        let entry = try requireDocument(document)
        let formHandle = try requireFormHandle(document)
        let pageCount = Int(FPDF_GetPageCount(entry.doc))

        var results: [FormField] = []
        var tabOrder = 0
        for pageIndex in 0..<pageCount {
            let pageHandle = try loadedPage(document, index: pageIndex)
            let annotCount = FPDFPage_GetAnnotCount(pageHandle)
            for annotIndex in 0..<annotCount {
                guard let annot = FPDFPage_GetAnnot(pageHandle, annotIndex) else { continue }
                defer { FPDFPage_CloseAnnot(annot) }
                guard FPDFAnnot_GetSubtype(annot) == FPDF_ANNOT_WIDGET else { continue }
                guard let field = Self.readField(
                    formHandle: formHandle, annot: annot, page: PageIndex(pageIndex), tabOrder: tabOrder
                ) else { continue }
                results.append(field)
                tabOrder += 1
            }
        }
        return results
    }

    public func setValue(_ value: String?, for fieldID: FormField.ID, in document: DocumentHandle) async throws {
        let entry = try requireDocument(document)
        let formHandle = try requireFormHandle(document)
        guard let located = try findWidget(matching: fieldID, formHandle: formHandle, document: entry.doc) else {
            throw PDFEngineError.fieldNotFound(fieldID)
        }
        let (annot, kind) = located

        let stringValue = value ?? ""
        guard Self.withWideString(stringValue, { FPDFAnnot_SetStringValue(annot, "V", $0) }) != 0 else {
            throw PDFEngineError.ioFailure("PDFium: failed to set form field value")
        }
        if kind == .checkbox || kind == .radioButton {
            // /AS (appearance state) selects which of the widget's /AP/N
            // sub-appearances is shown; PDF convention is "the export value"
            // when on, the literal name "Off" when off (ISO 32000-1
            // §12.7.4.2.3) — matches what `readField` treats as `exportValue`.
            let appearanceState = stringValue.isEmpty ? "Off" : stringValue
            guard Self.withWideString(appearanceState, { FPDFAnnot_SetStringValue(annot, "AS", $0) }) != 0 else {
                throw PDFEngineError.ioFailure("PDFium: failed to set form field appearance state")
            }
        }
    }

    // MARK: - Read one widget

    private static func readField(
        formHandle: FPDF_FORMHANDLE, annot: OpaquePointer, page: PageIndex, tabOrder: Int
    ) -> FormField? {
        guard let kind = formFieldKind(for: FPDFAnnot_GetFormFieldType(formHandle, annot)) else { return nil }

        let rawName = getFormFieldName(formHandle, annot) ?? ""
        let controlCount = FPDFAnnot_GetFormControlCount(formHandle, annot)
        let controlIndex = FPDFAnnot_GetFormControlIndex(formHandle, annot)
        let hasSiblings = controlCount > 1 && controlIndex >= 0
        let name = hasSiblings ? "\(rawName)#\(controlIndex)" : rawName
        let groupName = hasSiblings ? rawName : nil

        var rect = FS_RECTF(left: 0, top: 0, right: 0, bottom: 0)
        var boundingBox = PDFRect(x: 0, y: 0, width: 0, height: 0)
        if FPDFAnnot_GetRect(annot, &rect) != 0 {
            boundingBox = PDFRect(
                x: Double(rect.left), y: Double(rect.bottom),
                width: Double(rect.right - rect.left), height: Double(rect.top - rect.bottom)
            )
        }

        let flags = Int(FPDFAnnot_GetFormFieldFlags(formHandle, annot))
        let isReadOnly = flags & 0x1 != 0
        let isRequired = flags & 0x2 != 0
        // ISO 32000-1 Table 229 bit 25 (1-indexed) = Comb, text fields only.
        let isComb = kind == .text && flags & (1 << 24) != 0

        var maxLength: Int?
        var maxLenValue: Float = 0
        if FPDFAnnot_GetNumberValue(annot, "MaxLen", &maxLenValue) != 0, maxLenValue > 0 {
            maxLength = Int(maxLenValue)
        }
        let formatHint = (maxLength != nil || isComb)
            ? FormatHint(maxLength: maxLength, isComb: isComb)
            : nil

        var exportValue: String?
        if kind == .checkbox || kind == .radioButton {
            exportValue = getFormFieldExportValue(formHandle, annot)
        }

        var choiceOptions: [String] = []
        if kind == .choice || kind == .listBox {
            let optionCount = FPDFAnnot_GetOptionCount(formHandle, annot)
            if optionCount > 0 {
                choiceOptions = (0..<optionCount).compactMap { getOptionLabel(formHandle, annot, index: $0) }
            }
        }

        return FormField(
            name: name,
            page: page,
            rect: boundingBox,
            kind: kind,
            formatHint: formatHint,
            tooltip: getFormFieldAlternateName(formHandle, annot),
            tabOrder: tabOrder,
            isReadOnly: isReadOnly,
            currentValue: getFormFieldValue(formHandle, annot),
            exportValue: exportValue,
            groupName: groupName,
            choiceOptions: choiceOptions,
            isRequired: isRequired
        )
    }

    /// Re-walks the document exactly like `fields(of:)` to locate the widget
    /// backing `fieldID`, since `setValue` only receives an ID string, not a
    /// page hint. `kind` is returned alongside so the caller knows whether to
    /// also set `/AS`.
    private func findWidget(
        matching fieldID: FormField.ID, formHandle: FPDF_FORMHANDLE, document: OpaquePointer
    ) throws -> (annot: OpaquePointer, kind: FormFieldKind)? {
        let pageCount = Int(FPDF_GetPageCount(document))
        for pageIndex in 0..<pageCount {
            guard let pageHandle = FPDF_LoadPage(document, Int32(pageIndex)) else { continue }
            defer { FPDF_ClosePage(pageHandle) }
            let annotCount = FPDFPage_GetAnnotCount(pageHandle)
            for annotIndex in 0..<annotCount {
                guard let annot = FPDFPage_GetAnnot(pageHandle, annotIndex) else { continue }
                guard FPDFAnnot_GetSubtype(annot) == FPDF_ANNOT_WIDGET else {
                    FPDFPage_CloseAnnot(annot)
                    continue
                }
                guard let kind = Self.formFieldKind(for: FPDFAnnot_GetFormFieldType(formHandle, annot)) else {
                    FPDFPage_CloseAnnot(annot)
                    continue
                }
                let rawName = Self.getFormFieldName(formHandle, annot) ?? ""
                let controlCount = FPDFAnnot_GetFormControlCount(formHandle, annot)
                let controlIndex = FPDFAnnot_GetFormControlIndex(formHandle, annot)
                let hasSiblings = controlCount > 1 && controlIndex >= 0
                let name = hasSiblings ? "\(rawName)#\(controlIndex)" : rawName
                if name == fieldID { return (annot, kind) }
                FPDFPage_CloseAnnot(annot)
            }
        }
        return nil
    }

    // MARK: - Kind mapping

    private static func formFieldKind(for raw: Int32) -> FormFieldKind? {
        switch raw {
        case FPDF_FORMFIELD_PUSHBUTTON: .button
        case FPDF_FORMFIELD_CHECKBOX: .checkbox
        case FPDF_FORMFIELD_RADIOBUTTON: .radioButton
        case FPDF_FORMFIELD_COMBOBOX: .choice
        case FPDF_FORMFIELD_LISTBOX: .listBox
        case FPDF_FORMFIELD_TEXTFIELD: .text
        case FPDF_FORMFIELD_SIGNATURE: .signature
        default: nil // XFA_* kinds (8-15): this vendored build has no XFA module.
        }
    }

    // MARK: - Wide-string reads (same call-twice-for-length contract as PDFiumAnnotationStore)

    private static func withWideString<T>(_ string: String, _ body: (FPDF_WIDESTRING?) -> T) -> T {
        var units = Array(string.utf16)
        units.append(0)
        return units.withUnsafeBufferPointer { body($0.baseAddress) }
    }

    private static func getFormFieldName(_ handle: FPDF_FORMHANDLE, _ annot: OpaquePointer) -> String? {
        wideString { buffer, length in FPDFAnnot_GetFormFieldName(handle, annot, buffer, length) }
    }

    private static func getFormFieldAlternateName(_ handle: FPDF_FORMHANDLE, _ annot: OpaquePointer) -> String? {
        wideString { buffer, length in FPDFAnnot_GetFormFieldAlternateName(handle, annot, buffer, length) }
    }

    private static func getFormFieldValue(_ handle: FPDF_FORMHANDLE, _ annot: OpaquePointer) -> String? {
        wideString { buffer, length in FPDFAnnot_GetFormFieldValue(handle, annot, buffer, length) }
    }

    private static func getFormFieldExportValue(_ handle: FPDF_FORMHANDLE, _ annot: OpaquePointer) -> String? {
        wideString { buffer, length in FPDFAnnot_GetFormFieldExportValue(handle, annot, buffer, length) }
    }

    private static func getOptionLabel(_ handle: FPDF_FORMHANDLE, _ annot: OpaquePointer, index: Int32) -> String? {
        wideString { buffer, length in FPDFAnnot_GetOptionLabel(handle, annot, index, buffer, length) }
    }

    private static func wideString(_ call: (UnsafeMutablePointer<UInt16>?, UInt) -> UInt) -> String? {
        let byteLength = call(nil, 0)
        guard byteLength > 2 else { return nil }
        var units = [UInt16](repeating: 0, count: Int(byteLength) / 2)
        _ = units.withUnsafeMutableBufferPointer { buffer in call(buffer.baseAddress, byteLength) }
        if let nul = units.firstIndex(of: 0) { units.removeSubrange(nul...) }
        let result = String(decoding: units, as: UTF16.self)
        return result.isEmpty ? nil : result
    }
}
