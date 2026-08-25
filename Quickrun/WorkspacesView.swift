import SwiftUI

/// Dedicated tab for creating, editing, and deleting workspaces.
struct WorkspacesView: View {
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var l10n:           LanguageManager

    @State private var isAdding    = false
    @State private var editingWs:  Workspace? = nil
    @State private var deletingWs: Workspace? = nil
    @State private var dropTargetId: UUID?    = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title2)
                Text(l10n.t(.tabWorkspaces)).font(.title2).bold()
                Spacer()
                Button { isAdding = true } label: {
                    Label(l10n.t(.newWorkspace), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            if workspaceStore.workspaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(l10n.t(.noWorkspaces)).font(.title3).bold()
                    Text(l10n.t(.noWorkspacesHint))
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(workspaceStore.workspaces) { ws in
                            let count = actionStore.actions.filter { $0.workspaceId == ws.id }.count
                            WorkspaceTile(
                                workspace:    ws,
                                actionCount:  count,
                                isDropTarget: dropTargetId == ws.id,
                                onNavigate: {
                                    NotificationCenter.default.post(
                                        name:     .quickrunNavigateToActions,
                                        object:   nil,
                                        userInfo: ["workspaceId": ws.id]
                                    )
                                },
                                onStartAll: {
                                    runStore.startAll(actions: actionStore.actions.filter { $0.workspaceId == ws.id })
                                },
                                onEdit:   { editingWs  = ws },
                                onDelete: { deletingWs = ws }
                            )
                            .draggable(ws.id.uuidString)
                            .dropDestination(for: String.self) { items, _ in
                                guard
                                    let srcId  = items.first.flatMap(UUID.init),
                                    srcId != ws.id,
                                    let srcIdx = workspaceStore.workspaces.firstIndex(where: { $0.id == srcId }),
                                    let dstIdx = workspaceStore.workspaces.firstIndex(where: { $0.id == ws.id })
                                else { return false }
                                withAnimation {
                                    workspaceStore.move(
                                        from: IndexSet(integer: srcIdx),
                                        to:   dstIdx > srcIdx ? dstIdx + 1 : dstIdx
                                    )
                                }
                                return true
                            } isTargeted: { targeted in
                                dropTargetId = targeted ? ws.id : nil
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            WorkspaceFormView(mode: .create) { workspaceStore.add($0) }
        }
        .sheet(item: $editingWs) { ws in
            WorkspaceFormView(mode: .edit(ws)) { workspaceStore.update($0) }
        }
        .alert(item: $deletingWs) { ws in
            let count = actionStore.actions.filter { $0.workspaceId == ws.id }.count
            return Alert(
                title: Text(l10n.f(.deleteWorkspaceTitle, ws.name)),
                message: count == 0
                    ? Text(l10n.t(.deleteWorkspaceEmpty))
                    : Text(l10n.f(.deleteWorkspaceNonEmpty, count)),
                primaryButton: .destructive(Text(l10n.t(.delete))) {
                    workspaceStore.delete(ws)
                },
                secondaryButton: .cancel(Text(l10n.t(.cancel)))
            )
        }
    }
}

// MARK: - Workspace Tile

private struct WorkspaceTile: View {
    let workspace:    Workspace
    let actionCount:  Int
    var isDropTarget: Bool = false
    let onNavigate:   () -> Void
    let onStartAll:   () -> Void
    let onEdit:       () -> Void
    let onDelete:     () -> Void

    @EnvironmentObject var l10n: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: color + name + delete
            HStack(spacing: 8) {
                Circle()
                    .fill(workspace.color.color)
                    .frame(width: 12, height: 12)
                Text(workspace.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.red.opacity(0.7))
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .help(l10n.t(.delete))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(workspace.color.color.opacity(0.12))

            Divider()

            // Body: tappable → navigate to filtered actions
            Button(action: onNavigate) {
                HStack {
                    Label(
                        l10n.actionsCount(actionCount),
                        systemImage: "bolt.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Footer: start all + edit
            HStack(spacing: 0) {
                Button(action: onStartAll) {
                    Label(l10n.t(.startAll), systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .padding(.vertical, 9)
                .disabled(actionCount == 0)
                .opacity(actionCount == 0 ? 0.4 : 1)

                Divider().frame(height: 18)

                Button(action: onEdit) {
                    Label(l10n.t(.edit), systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 9)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDropTarget ? Color.accentColor : workspace.color.color.opacity(0.35),
                    lineWidth: isDropTarget ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .scaleEffect(isDropTarget ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }
}

// MARK: - Workspace Form

struct WorkspaceFormView: View {
    enum Mode { case create; case edit(Workspace) }
    let mode: Mode
    let onSave: (Workspace) -> Void

    @EnvironmentObject var l10n: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var name:  String         = ""
    @State private var color: WorkspaceColor = .blue

    private var title: String {
        if case .create = mode { return l10n.t(.newWorkspace) }
        return l10n.t(.editWorkspaceTitle)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2).bold()
                Spacer()
                Button(l10n.t(.cancel)) { dismiss() }.keyboardShortcut(.escape)
                Button(l10n.t(.save)) {
                    var ws: Workspace
                    switch mode {
                    case .create:      ws = Workspace(name: name.trimmingCharacters(in: .whitespaces), color: color)
                    case .edit(let e): ws = e; ws.name = name.trimmingCharacters(in: .whitespaces); ws.color = color
                    }
                    onSave(ws); dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(20)
            Divider()
            Form {
                TextField(l10n.t(.nameLabel), text: $name)
                Picker(l10n.t(.colorLabel), selection: $color) {
                    ForEach(WorkspaceColor.allCases) { c in
                        HStack {
                            Circle().fill(c.color).frame(width: 12, height: 12)
                            Text(c.label)
                        }
                        .tag(c)
                    }
                }
            }
            .formStyle(.grouped).padding(.horizontal, 4)
            Spacer()
        }
        .frame(minWidth: 360, minHeight: 240)
        .onAppear {
            if case .edit(let ws) = mode { name = ws.name; color = ws.color }
        }
    }
}

