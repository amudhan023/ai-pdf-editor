import Foundation

/// A contiguous run of text on a page, with its bounding geometry. Distinct
/// runs typically correspond to a content-stream text-showing operation, not
/// necessarily to whole words or lines.
public struct TextRun: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let page: PageIndex
    public let text: String
    public let boundingBox: PDFRect
    public let fontSize: Double

    public init(id: UUID = UUID(), page: PageIndex, text: String, boundingBox: PDFRect, fontSize: Double) {
        self.id = id
        self.page = page
        self.text = text
        self.boundingBox = boundingBox
        self.fontSize = fontSize
    }
}

/// Engine-neutral text extraction and in-place replacement. Replacement is
/// scoped to a single existing run — reflowing/inserting new runs is out of
/// scope for this protocol (belongs to a future editing-session layer).
public protocol TextEditor: Sendable {
    func textRuns(of document: DocumentHandle, page: PageIndex) async throws -> [TextRun]
    func replaceText(of document: DocumentHandle, run: TextRun.ID, with newText: String) async throws
}
