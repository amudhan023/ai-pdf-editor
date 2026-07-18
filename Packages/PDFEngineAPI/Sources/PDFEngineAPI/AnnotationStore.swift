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

/// One text-markup quadrilateral (PDF `/QuadPoints`, ISO 32000-1 Table 179):
/// one quad per marked line-segment, since a highlight/underline/strikeout/
/// squiggly can span multiple lines with different extents per line.
///
/// Named by corner rather than a flat `x1...y4` tuple because the spec's
/// literal text (a counter-clockwise quad) and real-world producer behavior
/// (Acrobat and most consumers write/expect "Z" order: top-left, top-right,
/// bottom-left, bottom-right) disagree — see ADR-014. `DocEngineHost`
/// follows the de facto Z order for interop.
public struct PDFQuad: Sendable, Codable, Equatable {
    public let topLeft: PDFPoint
    public let topRight: PDFPoint
    public let bottomLeft: PDFPoint
    public let bottomRight: PDFPoint

    public init(topLeft: PDFPoint, topRight: PDFPoint, bottomLeft: PDFPoint, bottomRight: PDFPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
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
    /// One quad per marked line; empty means "treat `boundingBox` as a
    /// single quad" (the case for subtypes with no quad semantics, e.g.
    /// square/circle/ink). See ADR-014.
    public let quadPoints: [PDFQuad]
    /// PDF `/CA` — annotation opacity, independent of `color`'s own alpha
    /// channel (ADR-014).
    public let opacity: Double
    public let createdAt: Date?

    public init(
        id: UUID = UUID(),
        page: PageIndex,
        subtype: AnnotationSubtype,
        boundingBox: PDFRect,
        color: AnnotationColor? = nil,
        contents: String? = nil,
        author: String? = nil,
        modifiedAt: Date? = nil,
        quadPoints: [PDFQuad] = [],
        opacity: Double = 1.0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.page = page
        self.subtype = subtype
        self.boundingBox = boundingBox
        self.color = color
        self.contents = contents
        self.author = author
        self.modifiedAt = modifiedAt
        self.quadPoints = quadPoints
        self.opacity = opacity
        self.createdAt = createdAt
    }
}

/// Engine-neutral annotation CRUD.
public protocol AnnotationStore: Sendable {
    func annotations(of document: DocumentHandle, page: PageIndex) async throws -> [Annotation]
    func add(_ annotation: Annotation, to document: DocumentHandle) async throws
    func update(_ annotation: Annotation, in document: DocumentHandle) async throws
    func remove(_ id: Annotation.ID, from document: DocumentHandle) async throws
}
