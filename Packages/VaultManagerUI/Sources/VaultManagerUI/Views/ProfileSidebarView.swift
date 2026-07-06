import SwiftUI
import VaultAPI

public struct ProfileSidebarView: View {
    @ObservedObject private var viewModel: ProfileListViewModel
    @Binding private var selection: PersonID?
    @State private var showAddSheet = false
    @State private var newName = ""
    @State private var newKind: PersonKind = .person

    public init(viewModel: ProfileListViewModel, selection: Binding<PersonID?>) {
        self.viewModel = viewModel
        self._selection = selection
    }

    public var body: some View {
        List(selection: $selection) {
            ForEach(viewModel.people) { person in
                Label(person.displayName, systemImage: person.kind == .organization ? "building.2" : "person")
                    .tag(person.id as PersonID?)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let id = viewModel.people[index].id
                    Task { await viewModel.deleteProfile(id) }
                }
            }
        }
        .toolbar {
            Button {
                showAddSheet = true
            } label: {
                Label("Add Profile", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New Profile").font(.headline)
                Picker("Type", selection: $newKind) {
                    Text("Person").tag(PersonKind.person)
                    Text("Organization").tag(PersonKind.organization)
                }
                .pickerStyle(.segmented)
                TextField("Display name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Cancel") { showAddSheet = false }
                    Spacer()
                    Button("Create") {
                        Task {
                            let created = await viewModel.createProfile(kind: newKind, displayName: newName)
                            newName = ""
                            showAddSheet = false
                            if let created { selection = created.id }
                        }
                    }
                    .disabled(newName.isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 280)
        }
    }
}
