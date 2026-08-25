import SwiftUI

/// Shows all configured actions as an advanced tile grid.
struct ActionsView: View {
    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var l10n:           LanguageManager

    @State private var filterWorkspaceId: UUID?   = nil
    @State private var isCreating                 = false
    @State private var editingAction:    Action?  = nil
    @State private var actionToTrash:    Action?  = nil
    @State private var logAction:        Action?  = nil
    @State private var showTrashAlert             = false
    @State private var dropTargetId:     UUID?    = nil

    private var filteredActions: [Action] {
        guard let id = filterWorkspaceId else {
            return actionStore.actions.filter { $0.workspaceId == nil }
        }
        return actionStore.actions.filter { $0.workspaceId == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            workspaceFilterBar
            if !workspaceStore.workspaces.isEmpty { Divider() }
            content
        }
        .sheet(isPresented: $isCreating) {
            ActionFormView(mode: .create, defaultWorkspaceId: filterWorkspaceId, onSave: { actionStore.add($0) })
                .environmentObject(workspaceStore)
        }
        .sheet(item: $editingAction) { action in
            ActionFormView(mode: .edit(action)) { actionStore.update($0) }
                .environmentObject(workspaceStore)
        }
        .sheet(item: $logAction) { action in
            ActionLogSheet(action: action)
                .environmentObject(runStore)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickrunNavigateToActions)) { notification in
            if let id = notification.userInfo?["workspaceId"] as? UUID {
                filterWorkspaceId = id
            }
        }
        .confirmationDialog(
            l10n.f(.deleteActionTitle, actionToTrash?.name ?? ""),
            isPresented: $showTrashAlert,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.moveToTrash), role: .destructive) {
                guard let action = actionToTrash else { return }
                if runStore.isRunning(actionId: action.id) { runStore.toggle(action: action) }
                actionStore.trash(action)
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            Text(l10n.t(.trashMessage))
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Color.accentColor)
                .font(.title2)
            Text(l10n.t(.tabActions)).font(.title2).bold()
            Spacer()
            Button { isCreating = true } label: {
                Label(l10n.t(.newAction), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 12)
    }

    // MARK: - Workspace filter bar

    @ViewBuilder
    private var workspaceFilterBar: some View {
        if !workspaceStore.workspaces.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(label: l10n.t(.all), color: nil, active: filterWorkspaceId == nil) {
                        filterWorkspaceId = nil
                    }
                    ForEach(workspaceStore.workspaces) { ws in
                        filterChip(label: ws.name, color: ws.color.color, active: filterWorkspaceId == ws.id) {
                            filterWorkspaceId = ws.id
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }

    private func filterChip(label: String, color: Color?, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(label).font(.subheadline).fontWeight(active ? .semibold : .regular)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(active ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor)))
            .overlay(Capsule().strokeBorder(active ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor), lineWidth: 1))
            .foregroundStyle(active ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tile grid

    @ViewBuilder
    private var content: some View {
        if filteredActions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "play.rectangle")
                    .font(.system(size: 48)).foregroundStyle(.secondary)
                Text(actionStore.actions.isEmpty ? l10n.t(.noActions) : l10n.t(.noActionsInWorkspace))
                    .font(.title3).bold()
                Text(actionStore.actions.isEmpty
                     ? l10n.t(.noActionsHint)
                     : l10n.t(.noWorkspaceActionsHint))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 14)],
                    spacing: 14
                ) {
                    ForEach(filteredActions) { action in
                        ActionTile(
                            action:       action,
                            isDropTarget: dropTargetId == action.id,
                            onEdit:       { editingAction = action },
                            onDelete:     { actionToTrash = action; showTrashAlert = true },
                            onLogs:       { logAction = action }
                        )
                        .draggable(action.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let srcId = items.first.flatMap(UUID.init),
                                  srcId != action.id
                            else { return false }
                            withAnimation { actionStore.move(from: srcId, to: action.id) }
                            return true
                        } isTargeted: { targeted in
                            dropTargetId = targeted ? action.id : nil
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Action Tile

private struct ActionTile: View {
    let action:       Action
    var isDropTarget: Bool = false
    let onEdit:       () -> Void
    let onDelete:     () -> Void
    let onLogs:       () -> Void

    @EnvironmentObject var runStore: RunStore
    @EnvironmentObject var l10n:     LanguageManager

    private var isRunning: Bool { runStore.isRunning(actionId: action.id) }

    private var lastRun: Run? {
        runStore.runs.first { $0.actionId == action.id }
    }

    private var tileBackground: Color {
        if isRunning { return Color.green.opacity(0.12) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.08)
        case .error:    return Color.orange.opacity(0.12)
        default:        return Color(NSColor.controlBackgroundColor)
        }
    }

    private var tileBorderColor: Color {
        if isRunning { return Color.green.opacity(0.4) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.35)
        case .error:    return Color.orange.opacity(0.4)
        default:        return Color(NSColor.separatorColor)
        }
    }

    private var tileBorderWidth: CGFloat { isRunning ? 1.5 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tileHeader
            Divider().padding(.horizontal, 12)
            tileBody
            Divider().padding(.horizontal, 12)
            tileFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 10).fill(tileBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isDropTarget ? Color.accentColor : tileBorderColor,
                    lineWidth: isDropTarget ? 2 : tileBorderWidth
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        .scaleEffect(isDropTarget ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
    }

    // Status bar + badges
    private var tileHeader: some View {
        HStack(spacing: 6) {
            // Running indicator
            Circle()
                .fill(isRunning ? Color.green : Color.red.opacity(0.6))
                .frame(width: 9, height: 9)
            Text(isRunning ? l10n.t(.statusRunning) : l10n.t(.statusIdle))
                .font(.caption2)
                .foregroundStyle(isRunning ? Color.green : Color.secondary)

            Spacer()

            // Port badge
            if let port = action.port {
                Text(":\(port)")
                    .font(.system(size: 10, design: .monospaced))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Color(NSColor.quaternaryLabelColor)))
                    .foregroundStyle(.secondary)
            }

            // Shell badge
            Text(action.shell.label)
                .font(.system(size: 10, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 2)
                .background(Capsule().fill(Color(NSColor.quaternaryLabelColor)))
                .foregroundStyle(.secondary)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.red.opacity(0.7))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help(l10n.t(.deleteActionHelp))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // Name + command + cwd
    private var tileBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.name)
                .font(.headline)
                .lineLimit(1)

            Text(action.command.components(separatedBy: .newlines).first ?? action.command)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label(
                action.workingDirectory.flatMap { $0.isEmpty ? nil : $0 } ?? " ",
                systemImage: "folder"
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .lineLimit(1)

            // Last run status
            HStack(spacing: 4) {
                if let run = lastRun {
                    Circle().fill(run.status.color).frame(width: 5, height: 5)
                    Text(l10n.f(.lastRun, run.startedAt.shortLabel, run.status.label))
                } else {
                    Circle().fill(Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                    Text(l10n.t(.neverRun))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Run / Edit / Logs buttons
    private var tileFooter: some View {
        HStack(spacing: 8) {
            // Run / Stop — primary action
            Button {
                runStore.toggle(action: action)
            } label: {
                Label(isRunning ? l10n.t(.stop) : l10n.t(.run),
                      systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .green)
            .controlSize(.small)

            // Edit
            Button { onEdit() } label: {
                Label(l10n.t(.edit), systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(l10n.t(.editActionHelp))

            // Logs
            Button { onLogs() } label: {
                Label(l10n.t(.logs), systemImage: "text.alignleft")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(l10n.t(.viewLogsHelp))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Log Sheet

/// Full-size log viewer for a specific action (all its runs).
struct ActionLogSheet: View {
    let action: Action

    @EnvironmentObject var runStore: RunStore
    @EnvironmentObject var l10n:     LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedRunId: UUID?

    private var actionRuns: [Run] {
        runStore.runs.filter { $0.actionId == action.id }
    }

    private var selectedRun: Run? {
        runStore.runs.first { $0.id == selectedRunId }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.f(.logsFor, action.name)).font(.title2).bold()
                    Text(l10n.runsCount(actionRuns.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(l10n.t(.done)) { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(20)

            Divider()

            if actionRuns.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text(l10n.t(.noRunsForAction))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geo in
                  HStack(spacing: 0) {
                    // Run list — 1/4
                    List(actionRuns, selection: $selectedRunId) { run in
                        HStack(spacing: 8) {
                            Circle().fill(run.status.color).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(run.startedAt, style: .date).font(.subheadline)
                                Text(run.startedAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(run.status.label).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                        .tag(run.id)
                    }
                    .frame(width: 220)
                    .onAppear { selectedRunId = actionRuns.first?.id }

                    Divider()

                    // Log viewer — 3/4
                    VStack(spacing: 0) {
                        if let run = selectedRun {
                            HStack {
                                Text(run.startedAt, format: .dateTime).font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text(run.status.label).font(.caption)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(run.status.color.opacity(0.15)))
                                    .foregroundStyle(run.status.color)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider()
                        }
                        LogsView(runId: selectedRunId)
                    }
                    .frame(maxWidth: .infinity)
                  }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
