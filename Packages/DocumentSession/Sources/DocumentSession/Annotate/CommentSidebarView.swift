import SwiftUI
import PDFEngineAPI

/// Document-wide list of sticky-note comments (P1-05) — see
/// `CommentSidebarViewModel`'s doc comment for the popup/list split and the
/// reply-free v1 scope cut.
struct CommentSidebarView: View {
    @ObservedObject var comments: CommentSidebarViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List(comments.comments) { comment in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author ?? "Anonymous")
                        .font(.headline)
                    Spacer()
                    Text("p. \(comment.page.value + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(comment.contents ?? "")
                    .font(.body)
                if let createdAt = comment.createdAt {
                    Text(Self.dateFormatter.string(from: createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { comments.select(comment) }
            .swipeActions {
                Button(role: .destructive) {
                    Task { await comments.delete(comment) }
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .overlay {
            if comments.comments.isEmpty {
                ContentUnavailableView("No Comments", systemImage: "bubble.left")
            }
        }
        .task { await comments.reload() }
    }
}
