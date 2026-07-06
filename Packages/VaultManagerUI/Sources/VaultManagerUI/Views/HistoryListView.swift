import SwiftUI
import VaultAPI

public struct HistoryListView: View {
    @ObservedObject private var viewModel: HistoryListViewModel
    @State private var showAddSheet = false
    @State private var newStart = Date()
    @State private var isOngoing = true
    @State private var newEnd = Date()

    public init(viewModel: HistoryListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            ForEach(viewModel.rows) { row in
                VStack(alignment: .leading) {
                    HStack {
                        Text(rangeLabel(row.entry.range))
                        if row.overlapsAnother {
                            Label("Overlaps another entry", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                    ForEach(row.entry.fields, id: \.path) { field in
                        Text("\(field.path.description): \(fieldValueDescription(field.value))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.deleteEntry(row.entry.id) }
                    }
                }
            }
        }
        .toolbar {
            Button {
                showAddSheet = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Start", selection: $newStart, displayedComponents: .date)
                Toggle("Ongoing", isOn: $isOngoing)
                if !isOngoing {
                    DatePicker("End", selection: $newEnd, displayedComponents: .date)
                }
                HStack {
                    Button("Cancel") { showAddSheet = false }
                    Spacer()
                    Button("Add") {
                        let range = DateRange(start: newStart, end: isOngoing ? nil : newEnd)
                        Task {
                            await viewModel.addEntry(range: range, fields: [])
                            showAddSheet = false
                        }
                    }
                }
            }
            .padding(20)
            .frame(minWidth: 280)
        }
        .task { await viewModel.refresh() }
    }

    private func rangeLabel(_ range: DateRange) -> String {
        let start = range.start.formatted(date: .abbreviated, time: .omitted)
        let end = range.end.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Present"
        return "\(start) – \(end)"
    }

    private func fieldValueDescription(_ value: FieldValue) -> String {
        switch value {
        case .string(let bytes): bytes.exposeAsPlaintext()
        case .date(let date): date.formatted(date: .abbreviated, time: .omitted)
        case .number(let number): String(number)
        case .enumeration(let raw): raw
        case .list(let values): values.map(fieldValueDescription).joined(separator: ", ")
        }
    }
}
