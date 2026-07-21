import XCTest
import PDFEngineAPI
@testable import DocumentSession

final class CommentSidebarViewModelTests: XCTestCase {
    @MainActor
    private func makeOpenSession() async throws -> DocumentSession {
        let engine = FakePDFEngine()
        let session = DocumentSession(lifecycle: engine, renderer: engine, annotationStore: engine)
        try await session.open(url: URL(fileURLWithPath: "/tmp/doesnotneedtoexist.pdf"))
        return session
    }

    private func note(page: PageIndex = PageIndex(0), author: String, contents: String) -> Annotation {
        Annotation(
            page: page, subtype: .text, boundingBox: PDFRect(x: 0, y: 0, width: 20, height: 20),
            contents: contents, author: author, createdAt: Date()
        )
    }

    @MainActor
    func testReloadCollectsOnlyTextSubtypeAnnotations() async throws {
        let session = try await makeOpenSession()
        try await session.addAnnotation(note(author: "Alice", contents: "Looks good"))
        try await session.addAnnotation(Annotation(
            page: PageIndex(0), subtype: .highlight, boundingBox: PDFRect(x: 0, y: 0, width: 10, height: 10)
        ))

        var navigated: PageIndex?
        let sidebar = CommentSidebarViewModel(session: session) { navigated = $0 }
        await sidebar.reload()

        XCTAssertEqual(sidebar.comments.count, 1)
        XCTAssertEqual(sidebar.comments.first?.author, "Alice")
        XCTAssertNil(navigated)
    }

    @MainActor
    func testSelectNavigatesToTheCommentsPage() async throws {
        let session = try await makeOpenSession()
        try await session.addAnnotation(note(author: "Bob", contents: "Check this"))
        var navigated: PageIndex?
        let sidebar = CommentSidebarViewModel(session: session) { navigated = $0 }
        await sidebar.reload()
        let comment = try XCTUnwrap(sidebar.comments.first)

        sidebar.select(comment)

        XCTAssertEqual(navigated, PageIndex(0))
    }

    @MainActor
    func testDeleteRemovesCommentAndReloads() async throws {
        let session = try await makeOpenSession()
        try await session.addAnnotation(note(author: "Carol", contents: "Fix typo"))
        let sidebar = CommentSidebarViewModel(session: session) { _ in }
        await sidebar.reload()
        let comment = try XCTUnwrap(sidebar.comments.first)

        await sidebar.delete(comment)

        XCTAssertEqual(sidebar.comments, [])
    }
}
