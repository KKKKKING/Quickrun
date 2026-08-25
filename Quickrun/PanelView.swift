import SwiftUI

/// The dropdown panel shown when the user clicks the menu bar icon.
struct PanelView: View {
    let openMainWindow: () -> Void

    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var runStore:       RunStore
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var l10n:           LanguageManager

    /// "all" or a UUID string — persisted so the filter survives panel close.
    @AppStorage("panelWorkspaceFilter") private var filterRaw: String = "all"

    /// Cards grid or compact list — configurable in Settings.
    @AppStorage(SettingsKey.panelStyle)    private var panelStyle: PanelStyle = .cards
    /// Whether the Logs section is shown at the bottom of the panel.
    @AppStorage(SettingsKey.panelShowLogs) private var showLogs: Bool = true

    /// The run whose log is currently expanded in the Logs section.
    @State private var expandedRunId: UUID?

    private var filteredActions: [Action] {
        guard filterRaw != "all", let id = UUID(uuidString: filterRaw) else {
            return actionStore.actions.filter { $0.workspaceId == nil }
        }
        return actionStore.actions.filter { $0.workspaceId == id }
    }

    /// The workspace currently selected in the filter bar, if any.
    private var selectedWorkspace: Workspace? {
        guard filterRaw != "all" else { return nil }
        return UUID(uuidString: filterRaw).flatMap { workspaceStore.workspace(for: $0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            workspaceFilter
            Divider()
            if selectedWorkspace != nil && !filteredActions.isEmpty {
                groupBar
                Divider()
            }
            actionsContent
            if showLogs {
                Divider()
                logsSection
            }
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image("QuickrunLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 29, height: 22)
            Text("Quickrun")
                .font(.headline)
            Spacer()
            Button(l10n.t(.openApp)) { openMainWindow() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Workspace filter

    private var workspaceFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                WorkspacePill(label: l10n.t(.all), color: nil, isSelected: filterRaw == "all") {
                    filterRaw = "all"
                }
                ForEach(workspaceStore.workspaces) { ws in
                    WorkspacePill(
                        label: ws.name,
                        color: ws.color.color,
                        isSelected: filterRaw == ws.id.uuidString
                    ) {
                        filterRaw = ws.id.uuidString
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Group batch bar (start all / stop all)

    private var groupBar: some View {
        let running = filteredActions.filter { runStore.isRunning(actionId: $0.id) }.count
        return HStack(spacing: 8) {
            Circle()
                .fill(running > 0 ? Color.green : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
            Text(l10n.f(.runningCount, running, filteredActions.count))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                runStore.startAll(actions: filteredActions)
            } label: {
                Label(l10n.t(.startAll), systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.green)
            .disabled(running == filteredActions.count)

            Button {
                runStore.stopAll(actions: filteredActions)
            } label: {
                Label(l10n.t(.stopAll), systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)
            .disabled(running == 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions (cards grid or compact list)

    @ViewBuilder
    private var actionsContent: some View {
        if filteredActions.isEmpty {
            Text(actionStore.actions.isEmpty
                 ? l10n.t(.noActionsYet)
                 : l10n.t(.noActionsInWorkspace))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
        } else {
            switch panelStyle {
            case .cards: cardsGrid
            case .list:  actionsList
            }
        }
    }

    private var cardsGrid: some View {
        Group {
            let grid = LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 82, maximum: 110), spacing: 8)],
                spacing: 8
            ) {
                ForEach(filteredActions) { action in
                    ActionTile(action: action)
                }
            }
            .padding(12)

            if filteredActions.count > 10 {
                // Many actions: cap height and enable scroll
                ScrollView { grid }.frame(maxHeight: 300)
            } else {
                // Few actions: show everything, no scroll, panel grows naturally
                grid
            }
        }
    }

    private var actionsList: some View {
        Group {
            let list = VStack(spacing: 0) {
                ForEach(filteredActions) { action in
                    ActionListRow(action: action)
                    if action.id != filteredActions.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .padding(.vertical, 6)

            if filteredActions.count > 8 {
                // Many actions: cap height and enable scroll
                ScrollView { list }.frame(maxHeight: 320)
            } else {
                list
            }
        }
    }

    // MARK: - Logs section

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l10n.t(.logs))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if !runStore.runs.isEmpty {
                    Button(l10n.t(.seeAll)) {
                        NotificationCenter.default.post(name: .quickrunNavigateToRuns, object: nil)
                        openMainWindow()
                    }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if runStore.runs.isEmpty {
                Text(l10n.t(.noRunsYet))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(runStore.runs.prefix(5)) { run in
                        RunLogRow(
                            run: run,
                            log: runStore.log(for: run.id),
                            isExpanded: expandedRunId == run.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    expandedRunId = expandedRunId == run.id ? nil : run.id
                                }
                            }
                        )
                        if run.id != runStore.runs.prefix(5).last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Workspace pill

private struct WorkspacePill: View {
    let label:      String
    let color:      Color?
    let isSelected: Bool
    let action:     () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
                Text(label).font(.caption).fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(isSelected
                               ? Color.accentColor.opacity(0.15)
                               : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor),
                    lineWidth: 1
                )
            )
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action tile (cards mode)

/// Cards mode: tap to start when idle, tap again to stop.
private struct ActionTile: View {
    let action: Action

    @EnvironmentObject var runStore: RunStore
    @EnvironmentObject var l10n:     LanguageManager

    private var isRunning: Bool { runStore.isRunning(actionId: action.id) }
    private var lastRun: Run? { runStore.runs.first { $0.actionId == action.id } }

    private var tileBackground: Color {
        if isRunning { return Color.green.opacity(0.12) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.08)
        case .error:    return Color.orange.opacity(0.12)
        default:        return Color(NSColor.controlBackgroundColor)
        }
    }

    private var tileBorder: Color {
        if isRunning { return Color.green.opacity(0.4) }
        switch lastRun?.status {
        case .finished: return Color.blue.opacity(0.35)
        case .error:    return Color.orange.opacity(0.4)
        default:        return Color(NSColor.separatorColor)
        }
    }

    var body: some View {
        Button { runStore.toggle(action: action) } label: {
            VStack(spacing: 5) {
                Text(action.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let port = action.port {
                    Text(verbatim: ":\(port)")
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(Color(NSColor.quaternaryLabelColor)))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(tileBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(tileBorder, lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .help(isRunning ? l10n.f(.stopAction, action.name) : l10n.f(.runAction, action.name))
    }
}

// MARK: - Action row (list mode)

/// List mode: one compact row per action with a start/stop icon reflecting state.
private struct ActionListRow: View {
    let action: Action

    @EnvironmentObject var runStore: RunStore
    @EnvironmentObject var l10n:     LanguageManager

    private var isRunning: Bool { runStore.isRunning(actionId: action.id) }
    private var lastRun: Run? { runStore.runs.first { $0.actionId == action.id } }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isRunning ? Color.green : Color.red.opacity(0.6))
                .frame(width: 8, height: 8)

            Text(action.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if let port = action.port {
                Text(verbatim: ":\(port)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(Color(NSColor.quaternaryLabelColor)))
            }

            Spacer()

            if let lastRun {
                Text(lastRun.startedAt.shortLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button { runStore.toggle(action: action) } label: {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isRunning ? Color.red : Color.green)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill((isRunning ? Color.red : Color.green).opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help(isRunning ? l10n.f(.stopAction, action.name) : l10n.f(.runAction, action.name))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

// MARK: - Run log row

private struct RunLogRow: View {
    let run:        Run
    let log:        String
    let isExpanded: Bool
    let onToggle:   () -> Void

    @EnvironmentObject var l10n: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(run.status.color)
                        .frame(width: 8, height: 8)
                    Text(run.actionName)
                        .font(.caption)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(run.startedAt.shortLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable log preview
            if isExpanded {
                let preview = lastLines(of: log, count: 7)
                ScrollView {
                    Text(preview.isEmpty ? l10n.t(.noOutput) : preview)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(preview.isEmpty ? Color.secondary : Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 7 * 15)   // 7 lines × ~15 pt line height
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func lastLines(of text: String, count: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        return lines.suffix(count).joined(separator: "\n")
    }
}
