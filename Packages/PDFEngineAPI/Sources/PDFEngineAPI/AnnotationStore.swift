import Foundation

/// Annotation subtypes, mirroring the PDF spec's `/Subtype` values for
/// markup annotations (ISO 32000-1 §12.5.6) — only the subtypes this product
/// actually supports creating/editing, not the full spec list.
public enum AnnotationSubtype: String, Sendable, Codable, CaseIterable {
    case text
    case highlight
    case underline
    case strikeOut
    case squiggly
    case ink
    case square
    case circle
    case line
    case freeText
    case stamp
    case popup
}

/// Opaque RGBA color, 0...1 per channel — engine-neutral so this package
/// never depends on AppKit/SwiftUI color types.
public struct AnnotationColor: Sendable, Codable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

public struct Annotation: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let page: PageIndex
    public let subtype: AnnotationSubtype
    public let boundingBox: PDFRect
    public let color: AnnotationColor?
    public let contents: String?
    public let author: String?
    public let modifiedAt: Date?

    public init(
        id: UUID = UUID(),
        page: PageIndex,
        subtype: AnnotationSubtype,
        boundingBox: PDFRect,
        color: AnnotationColor? = nil,
        contents: String? = nil,
        author: String? = nil,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.page = page
        self.subtype = subtype
        self.boundingBox = boundingBox
        self.color = color
        self.contents = contents
        self.author = author
        self.modifiedAt = modifiedAt
    }
}

/// Engine-neutral annotation CRUD.
public protocol AnnotationStore: Sendable {
    func annotations(of document: DocumentHandle, page: PageIndex) async throws -> [Annotation]
    func add(_ annotation: Annotation, to document: DocumentHandle) async throws
    func update(_ annotation: Annotation, in document: DocumentHandle) async throws
    func remove(_ id: Annotation.ID, from document: DocumentHandle) async throws
}
