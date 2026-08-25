import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

/// App-level settings: appearance, startup, data, and app info.
struct SettingsView: View {
    @AppStorage(SettingsKey.theme)         private var theme:         AppTheme   = .system
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin: Bool       = false
    @AppStorage(SettingsKey.panelStyle)    private var panelStyle:    PanelStyle = .cards
    @AppStorage(SettingsKey.panelShowLogs) private var panelShowLogs: Bool       = true

    @EnvironmentObject var actionStore:    ActionStore
    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var l10n:           LanguageManager

    @State private var showImportConfirm = false
    @State private var pendingImport:    ExportBundle? = nil
    @State private var exportError:      String?       = nil
    @State private var importError:      String?       = nil
    @State private var showResetSheet    = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l10n.t(.tabSettings)).font(.title2).bold()
                Spacer()
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            Form {
                Section(l10n.t(.appearance)) {
                    Picker(l10n.t(.theme), selection: $theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker(l10n.t(.language), selection: $l10n.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(l10n.t(.menuBarPanel)) {
                    Picker(l10n.t(.panelStyle), selection: $panelStyle) {
                        ForEach(PanelStyle.allCases) { style in
                            Text(style.label).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(l10n.t(.panelShowLogs), isOn: $panelShowLogs)
                }

                Section(l10n.t(.startup)) {
                    Toggle(l10n.t(.launchAtLogin), isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { enabled in
                            setLaunchAtLogin(enabled)
                        }
                }

                Section(l10n.t(.dataSection)) {
                    LabeledContent(l10n.t(.exportLabel)) {
                        Button(l10n.t(.exportButton)) { exportData() }
                            .buttonStyle(.bordered)
                    }
                    if let err = exportError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    LabeledContent(l10n.t(.importLabel)) {
                        Button(l10n.t(.importButton)) { importData() }
                            .buttonStyle(.bordered)
                    }
                    if let err = importError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    LabeledContent("") {
                        Text(l10n.t(.importHint))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent(l10n.t(.resetLabel)) {
                        Button(l10n.t(.resetButton)) { showResetSheet = true }
                            .buttonStyle(.bordered)
                            .tint(.red)
                    }
                }

                Section(l10n.t(.about)) {
                    VStack(spacing: 16) {
                        Image("QuickrunTitle")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 48)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        HStack(spacing: 24) {
                            Label(
                                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                                systemImage: "tag"
                            )
                            .foregroundStyle(.secondary)
                            .font(.subheadline)

                            Link(destination: URL(string: "https://github.com/KKKKKING/Quickrun")!) {
                                Label("GitHub", systemImage: "arrow.up.right.square")
                                    .font(.subheadline)
                            }
                        }

                        Text(l10n.t(.aboutNote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)

            Spacer()
        }
        .sheet(isPresented: $showResetSheet) {
            ResetConfirmSheet {
                actionStore.actions.forEach    { actionStore.trash($0) }
                actionStore.emptyTrash()
                workspaceStore.workspaces.forEach { workspaceStore.delete($0) }
            }
            .environmentObject(l10n)
        }
        .confirmationDialog(
            l10n.t(.importConfirmTitle),
            isPresented: $showImportConfirm,
            titleVisibility: .visible
        ) {
            Button(l10n.t(.importReplace), role: .destructive) {
                guard let bundle = pendingImport else { return }
                applyImport(bundle)
            }
            Button(l10n.t(.cancel), role: .cancel) {}
        } message: {
            if let bundle = pendingImport {
                Text(l10n.f(.importSummary, bundle.actions.count, bundle.workspaces.count))
            }
        }
    }

    // MARK: - Export

    private func exportData() {
        exportError = nil
        let bundle = ExportBundle(
            actions:    actionStore.actions,
            workspaces: workspaceStore.workspaces
        )
        guard let data = try? JSONEncoder().encode(bundle) else {
            exportError = l10n.t(.errorEncoding)
            return
        }

        let panel = NSSavePanel()
        panel.title              = l10n.t(.exportPanelTitle)
        panel.nameFieldStringValue = "quickrun-export"
        panel.allowedContentTypes  = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            exportError = l10n.f(.errorWriteFile, error.localizedDescription)
        }
    }

    // MARK: - Import

    private func importData() {
        importError = nil
        let panel = NSOpenPanel()
        panel.title               = l10n.t(.importPanelTitle)
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data   = try Data(contentsOf: url)
            let bundle = try JSONDecoder().decode(ExportBundle.self, from: data)
            pendingImport    = bundle
            showImportConfirm = true
        } catch {
            importError = l10n.t(.errorInvalidFile)
        }
    }

    private func applyImport(_ bundle: ExportBundle) {
        // Only add workspaces that don't already exist (compared by ID)
        let existingIds = Set(workspaceStore.workspaces.map { $0.id })
        bundle.workspaces
            .filter { !existingIds.contains($0.id) }
            .forEach { workspaceStore.add($0) }

        // Replace all actions
        for action in actionStore.actions { actionStore.trash(action) }
        bundle.actions.forEach { actionStore.add($0) }
    }

    // MARK: - Launch at login

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else        { try SMAppService.mainApp.unregister() }
        } catch {
            // SMAppService may fail outside a properly signed bundle.
        }
    }
}

// MARK: - Reset confirmation sheet

private struct ResetConfirmSheet: View {
    let onConfirm: () -> Void

    @EnvironmentObject var l10n: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var typed = ""

    private let keyword = "RESET"
    private var isValid: Bool { typed.uppercased() == keyword }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text(l10n.t(.resetTitle))
                .font(.title2).bold()

            Text(l10n.t(.resetMessage))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.f(.resetTypeHint, keyword))
                    .font(.subheadline)
                TextField("", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 200)
            }

            HStack(spacing: 12) {
                Button(l10n.t(.cancel)) { dismiss() }
                    .keyboardShortcut(.escape)
                Button(l10n.t(.resetLabel)) {
                    onConfirm()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(!isValid)
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

// MARK: - Export bundle

struct ExportBundle: Codable {
    var actions:    [Action]
    var workspaces: [Workspace]
}
