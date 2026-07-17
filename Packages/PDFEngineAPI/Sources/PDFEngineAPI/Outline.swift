import Foundation

/// One entry in a document's outline/bookmark tree (PDF spec `/Outlines`).
/// `destinationPage` is `nil` for a structural heading with no page target;
/// `zoom` is the destination's target zoom level, when the PDF specifies one.
public struct OutlineNode: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let destinationPage: PageIndex?
    public let zoom: Double?
    public let children: [OutlineNode]

    public init(
        id: UUID = UUID(),
        title: String,
        destinationPage: PageIndex?,
        zoom: Double? = nil,
        children: [OutlineNode] = []
    ) {
        self.id = id
        self.title = title
        self.destinationPage = destinationPage
        self.zoom = zoom
        self.children = children
    }
}

/// Engine-neutral document outline (table of contents) read. An empty array
/// means the document has no outline — not an error.
public protocol OutlineReader: Sendable {
    func outline(of document: DocumentHandle) async throws -> [OutlineNode]
}
