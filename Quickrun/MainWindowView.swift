import SwiftUI

/// Root view of the main Quickrun window.
struct MainWindowView: View {
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var l10n:           LanguageManager

    enum Tab: String, CaseIterable, Identifiable {
        case workspaces = "Workspaces"
        case actions    = "Actions"
        case runs       = "Runs & Logs"
        case trash      = "Trash"
        case settings   = "Settings"

        var id: String { rawValue }

        var titleKey: L10nKey {
            switch self {
            case .workspaces: return .tabWorkspaces
            case .actions:    return .tabActions
            case .runs:       return .tabRuns
            case .trash:      return .tabTrash
            case .settings:   return .tabSettings
            }
        }

        var icon: String {
            switch self {
            case .workspaces: return "folder.fill"
            case .actions:    return "bolt.fill"
            case .runs:       return "clock.fill"
            case .trash:      return "trash.fill"
            case .settings:   return "gearshape.fill"
            }
        }
    }

    @State private var selectedTab:     Tab  = .workspaces
    @State private var showQuitConfirm: Bool = false

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selectedTab) { tab in
                Label(l10n.t(tab.titleKey), systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 155, ideal: 175)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(role: .destructive) {
                    showQuitConfirm = true
                } label: {
                    Label(l10n.t(.quitQuickrun), systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .confirmationDialog(
                l10n.t(.quitConfirm),
                isPresented: $showQuitConfirm,
                titleVisibility: .visible
            ) {
                Button(l10n.t(.quit), role: .destructive) {
                    runStore.stopAll()
                    NSApp.terminate(nil)
                }
                Button(l10n.t(.cancel), role: .cancel) {}
            } message: {
                Text(runStore.runs.filter { $0.status == .running }.isEmpty
                     ? l10n.t(.quitMessageNoRuns)
                     : l10n.t(.quitMessageRunning))
            }
        } detail: {
            Group {
                switch selectedTab {
                case .actions:
                    ActionsView()
                case .runs:
                    RunsView()
                case .workspaces:
                    WorkspacesView()
                        .environmentObject(workspaceStore)
                        .environmentObject(actionStore)
                case .trash:
                    TrashView()
                        .environmentObject(actionStore)
                case .settings:
                    SettingsView()
                        .environmentObject(actionStore)
                        .environmentObject(workspaceStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Quickrun")
        .onReceive(NotificationCenter.default.publisher(for: .quickrunNavigateToRuns)) { _ in
            selectedTab = .runs
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickrunNavigateToActions)) { _ in
            selectedTab = .actions
        }
    }
}
