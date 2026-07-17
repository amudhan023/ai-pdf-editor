import SwiftUI

/// Search field + match counter + next/previous navigation, hosted in the
/// viewer toolbar. Incremental: every keystroke restarts the streaming scan.
struct SearchBarView: View {
    @ObservedObject var search: SearchViewModel
    @State private var text = ""

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onChange(of: text) { _, newValue in
                    search.updateQuery(newValue)
                }
            if search.isSearching {
                ProgressView()
                    .controlSize(.small)
            }
            if !text.isEmpty {
                Text(matchCounter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Button {
                search.previousResult()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(search.results.isEmpty)
            .keyboardShortcut("g", modifiers: [.command, .shift])
            Button {
                search.nextResult()
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(search.results.isEmpty)
            .keyboardShortcut("g", modifiers: .command)
        }
    }

    private var matchCounter: String {
        guard !search.results.isEmpty else {
            return search.isSearching ? "…" : "0"
        }
        let position = (search.currentResultIndex ?? 0) + 1
        return "\(position)/\(search.results.count)\(search.isSearching ? "+" : "")"
    }
}
