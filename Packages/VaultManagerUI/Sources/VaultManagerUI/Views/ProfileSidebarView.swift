import SwiftUI
import VaultAPI

/// Profile list + add-person affordance + a simple relationship editor
/// between two already-created profiles.
public struct ProfileSidebarView: View {
    @ObservedObject var viewModel: ProfileListViewModel

    @State private var newName = ""
    @State private var newKind: PersonKind = .person
    @State private var relateFrom: PersonID?
    @State private var relateTo: PersonID?
    @State private var relateKind: RelationshipKind = .spouse

    public init(viewModel: ProfileListViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading) {
            List(viewModel.persons, selection: $viewModel.selectedPersonID) { person in
                HStack {
                    Text(person.displayName)
                    Spacer()
                    Button(role: .destructive) {
                        Task { await viewModel.deletePerson(person.id) }
                    } label: { Image(systemName: "minus.circle") }
                }
                .tag(person.id)
            }

            Divider()
            HStack {
                Picker("Kind", selection: $newKind) {
                    Text("Person").tag(PersonKind.person)
                    Text("Organization").tag(PersonKind.organization)
                }
                TextField("Name", text: $newName)
                Button("Add") {
                    Task {
                        await viewModel.createPerson(kind: newKind, displayName: newName)
                        newName = ""
                    }
                }
                .disabled(newName.isEmpty)
            }
            .padding(.horizontal)

            if viewModel.persons.count >= 2 {
                Divider()
                Text("Add Relationship").font(.caption).bold()
                HStack {
                    Picker("From", selection: $relateFrom) {
                        ForEach(viewModel.persons) { Text($0.displayName).tag(Optional($0.id)) }
                    }
                    Picker("To", selection: $relateTo) {
                        ForEach(viewModel.persons) { Text($0.displayName).tag(Optional($0.id)) }
                    }
                    Button("Link") {
                        guard let from = relateFrom, let to = relateTo else { return }
                        Task { await viewModel.addRelationship(from: from, to: to, kind: relateKind) }
                    }
                    .disabled(relateFrom == nil || relateTo == nil)
                }
                .padding(.horizontal)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.caption).padding(.horizontal)
            }
        }
    }
}
