import SwiftUI
import VaultAPI

/// The vault window's root: `UnlockView` while locked, otherwise a
/// sidebar/detail split. Screenshot exclusion (CLAUDE.md's `sharingType`
/// requirement) is a property of the `NSWindow` this view is hosted in, not
/// of the view itself — the composition root that creates that window must
/// set `window.sharingType = .none`; this package doesn't create windows, so
/// it can't enforce that here. Documented as a call-site contract, not
/// silently dropped.
public struct VaultWindowView: View {
    @ObservedObject var unlock: VaultUnlockViewModel
    @ObservedObject var profiles: ProfileListViewModel
    let detailViewModel: (PersonID) -> ProfileDetailViewModel

    public init(
        unlock: VaultUnlockViewModel,
        profiles: ProfileListViewModel,
        detailViewModel: @escaping (PersonID) -> ProfileDetailViewModel
    ) {
        self.unlock = unlock
        self.profiles = profiles
        self.detailViewModel = detailViewModel
    }

    public var body: some View {
        Group {
            if unlock.lockState == .locked {
                UnlockView(viewModel: unlock)
            } else {
                NavigationSplitView {
                    ProfileSidebarView(viewModel: profiles)
                } detail: {
                    if let personID = profiles.selectedPersonID {
                        SectionDetailView(
                            viewModel: detailViewModel(personID),
                            onReauth: { Task { await unlock.unlock() } }
                        )
                    } else {
                        Text("Select a profile").foregroundStyle(.secondary)
                    }
                }
                .sheet(item: Binding(
                    get: { unlock.recoveryCode.map(RecoveryCodeSheetItem.init) },
                    set: { _ in }
                )) { item in
                    RecoveryCodeRevealView(code: item.code, dismiss: { unlock.dismissRecoveryCode() })
                }
                .toolbar {
                    ToolbarItem {
                        Button("Lock") { Task { await unlock.lock() } }
                    }
                }
            }
        }
        .onAppear { unlock.noteActivity() }
        .task { await unlock.refreshLockState() }
    }
}

private struct RecoveryCodeSheetItem: Identifiable {
    let code: String
    var id: String { code }
}
