import SwiftUI
import VaultAPI

/// One history category's entries (PRD FR-2.1's "history w/ date ranges").
/// Overlap warning is advisory only — `ProfileDetailViewModel.overlaps`
/// never blocks a save, real life has legitimate overlaps (e.g. two
/// part-time jobs).
struct HistoryListSection: View {
    let category: HistoryCategory
    @ObservedObject var viewModel: ProfileDetailViewModel

    @State private var newStart = Date()
    @State private var newEnd: Date?
    @State private var isOngoing = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.capitalized).font(.headline)
            ForEach(viewModel.history[category] ?? []) { entry in
                let overlapping = viewModel.overlaps(with: entry.range, category: category, excluding: entry.id)
                VStack(alignment: .leading) {
                    HStack {
                        Text(rangeDescription(entry.range))
                        Spacer()
                        Button(role: .destructive) {
                            Task { await viewModel.deleteHistoryEntry(entry.id, category: category) }
                        } label: { Image(systemName: "trash") }
                    }
                    if !overlapping.isEmpty {
                        Text("⚠️ Overlaps \(overlapping.count) other entry/entries")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            HStack {
                DatePicker("Start", selection: $newStart, displayedComponents: .date)
                Toggle("Ongoing", isOn: $isOngoing)
                if !isOngoing {
                    DatePicker("End", selection: Binding(get: { newEnd ?? Date() }, set: { newEnd = $0 }), displayedComponents: .date)
                }
                Button("Add") {
                    Task {
                        let entry = HistoryEntry(
                            personID: viewModel.personID,
                            category: category,
                            range: DateRange(start: newStart, end: isOngoing ? nil : newEnd)
                        )
                        await viewModel.writeHistoryEntry(entry)
                    }
                }
            }
        }
        .task { await viewModel.loadHistory(category) }
    }

    private func rangeDescription(_ range: DateRange) -> String {
        let start = range.start.formatted(date: .abbreviated, time: .omitted)
        let end = range.end.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "present"
        return "\(start) – \(end)"
    }
}
