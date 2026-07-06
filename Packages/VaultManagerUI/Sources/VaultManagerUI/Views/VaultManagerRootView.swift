import SwiftUI
import VaultAPI

/// The vault window's composition root: unlock gate, profile sidebar, and
/// detail pane. Screenshot-excluded per FR-2.5. Known person IDs are
/// supplied by the caller (`knownPersonIDs`) since `VaultClient` has no
/// "list all persons" method — the app-level session is the source of
/// truth for which profiles exist.
public struct VaultManagerRootView: View {
    @ObservedObject private var unlockViewModel: VaultUnlockViewModel
    @ObservedObject private var profileList: ProfileListViewModel
    private let knownPersonIDs: [PersonID]
    private let makeDetailViewModel: (PersonID) -> ProfileDetailViewModel
    private let makeRelationshipsViewModel: (PersonID) -> RelationshipsViewModel

    @State private var selection: PersonID?

    public init(
        unlockViewModel: VaultUnlockViewModel,
        profileList: ProfileListViewModel,
        knownPersonIDs: [PersonID],
        makeDetailViewModel: @escaping (PersonID) -> ProfileDetailViewModel,
        makeRelationshipsViewModel: @escaping (PersonID) -> RelationshipsViewModel
    ) {
        self.unlockViewModel = unlockViewModel
        self.profileList = profileList
        self.knownPersonIDs = knownPersonIDs
        self.makeDetailViewModel = makeDetailViewModel
        self.makeRelationshipsViewModel = makeRelationshipsViewModel
    }

    public var body: some View {
        Group {
            if unlockViewModel.lockState == .locked {
                VaultUnlockView(viewModel: unlockViewModel)
            } else {
                NavigationSplitView {
                    ProfileSidebarView(viewModel: profileList, selection: $selection)
                } detail: {
                    if let selection {
                        ProfileDetailView(viewModel: makeDetailViewModel(selection))
                    } else {
                        Text("Select a profile").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .excludedFromScreenCapture()
        .task { await unlockViewModel.refreshLockState() }
        .task(id: unlockViewModel.lockState) {
            guard unlockViewModel.lockState == .unlocked else { return }
            await profileList.refresh(known: knownPersonIDs)
        }
    }
}
