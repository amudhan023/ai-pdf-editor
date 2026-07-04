import Foundation

/// AcroForm field widget kind (PDF spec `/FT` field type, split further where
/// the UI treats them differently — e.g. radio buttons vs. plain checkboxes).
public enum FormFieldKind: String, Sendable, Codable, CaseIterable {
    case text
    case checkbox
    case radioButton
    case choice
    case listBox
    case signature
    case button
}

/// Formatting hints carried on a field (PDF "format" JavaScript actions are
/// parsed as hints only, never evaluated — CLAUDE.md §7.5).
public struct FormatHint: Sendable, Codable, Equatable {
    public let formatString: String?
    public let maxLength: Int?
    public let isComb: Bool

    public init(formatString: String? = nil, maxLength: Int? = nil, isComb: Bool = false) {
        self.formatString = formatString
        self.maxLength = maxLength
        self.isComb = isComb
    }
}

/// One node in the typed AcroForm field tree. `id` is the fully-qualified
/// field name (dot-separated per the PDF spec), which is also this product's
/// stable identity for the field across reads.
public struct FormField: Sendable, Codable, Equatable, Identifiable {
    public var id: String { name }

    public let name: String
    public let page: PageIndex
    public let rect: PDFRect
    public let kind: FormFieldKind
    public let formatHint: FormatHint?
    public let tooltip: String?
    public let tabOrder: Int
    public let isReadOnly: Bool
    public let currentValue: String?

    public init(
        name: String,
        page: PageIndex,
        rect: PDFRect,
        kind: FormFieldKind,
        formatHint: FormatHint? = nil,
        tooltip: String? = nil,
        tabOrder: Int,
        isReadOnly: Bool = false,
        currentValue: String? = nil
    ) {
        self.name = name
        self.page = page
        self.rect = rect
        self.kind = kind
        self.formatHint = formatHint
        self.tooltip = tooltip
        self.tabOrder = tabOrder
        self.isReadOnly = isReadOnly
        self.currentValue = currentValue
    }
}

/// Engine-neutral AcroForm field tree read/write.
public protocol FormModel: Sendable {
    func fields(of document: DocumentHandle) async throws -> [FormField]
    func setValue(_ value: String?, for fieldID: FormField.ID, in document: DocumentHandle) async throws
}
