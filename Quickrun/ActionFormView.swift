import SwiftUI
import AppKit

/// Modal sheet for creating or editing an action.
struct ActionFormView: View {
    enum Mode {
        case create
        case edit(Action)
    }

    let mode:               Mode
    var defaultWorkspaceId: UUID? = nil
    let onSave:             (Action) -> Void

    @EnvironmentObject var workspaceStore: WorkspaceStore
    @EnvironmentObject var l10n: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var name:              String  = ""
    @State private var command:           String  = ""
    @State private var stopCommand:       String  = ""
    @State private var shell:             Shell   = .bash
    @State private var workspaceId:       UUID?   = nil
    @State private var usesShellProfile:  Bool    = true
    @State private var workingDirectory:  String  = ""
    @State private var envText:           String  = ""   // "KEY=VALUE" per line
    @State private var timeoutText:       String  = ""   // seconds, empty = none

    private var title: String {
        switch mode {
        case .create: return l10n.t(.newAction)
        case .edit:   return l10n.t(.editActionTitle)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    basicSection
                    scriptSection
                    optionalSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 600, minHeight: 560)
        .onAppear { populate() }
    }

    // MARK: - Sections

    private var headerBar: some View {
        HStack {
            Text(title).font(.title2).bold()
            Spacer()
            Button(l10n.t(.cancel)) { dismiss() }
                .keyboardShortcut(.escape)
            Button(l10n.t(.save)) { saveAndDismiss() }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(20)
    }

    private var basicSection: some View {
        FormSection(title: l10n.t(.actionSection)) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.nameLabel))
                    TextField(l10n.t(.namePlaceholder), text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.workspaceLabel))
                    Picker("", selection: $workspaceId) {
                        Text(l10n.t(.none)).tag(UUID?.none)
                        ForEach(workspaceStore.workspaces) { ws in
                            HStack {
                                Circle().fill(ws.color.color).frame(width: 8, height: 8)
                                Text(ws.name)
                            }
                            .tag(Optional(ws.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    private var scriptSection: some View {
        FormSection(title: l10n.t(.scriptSection)) {
            VStack(alignment: .leading, spacing: 12) {
                // Multiline script editor
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.contentLabel))
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                        TextEditor(text: $command)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                    }
                    .frame(minHeight: 180)
                    Text(l10n.t(.contentHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Stop command editor
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.stopCommandLabel))
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                        TextEditor(text: $stopCommand)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                    }
                    .frame(minHeight: 56)
                    Text(l10n.t(.stopCommandHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Shell picker
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.shellLabel))
                    Picker("", selection: $shell) {
                        ForEach(Shell.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }

                // Shell profile toggle
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(isOn: $usesShellProfile) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l10n.t(.loadShellProfile))
                                .font(.body)
                            Text(shell == .bash
                                 ? l10n.t(.bashProfileHint)
                                 : l10n.t(.zshProfileHint))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var optionalSection: some View {
        FormSection(title: l10n.t(.optionsSection)) {
            VStack(alignment: .leading, spacing: 12) {
                // Working directory picker
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.workingDirectory))
                    HStack(spacing: 8) {
                        TextField(l10n.t(.workingDirectoryPlaceholder), text: $workingDirectory)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button {
                            pickFolder()
                        } label: {
                            Image(systemName: "folder")
                        }
                        .help(l10n.t(.chooseFolder))
                        if !workingDirectory.isEmpty {
                            Button {
                                workingDirectory = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help(l10n.t(.clearHint))
                        }
                    }
                }

                // Environment variables
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.envVars))
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color(NSColor.separatorColor), lineWidth: 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(NSColor.textBackgroundColor))
                            )
                        TextEditor(text: $envText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                    }
                    .frame(minHeight: 72)
                    Text(l10n.t(.envHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Timeout
                VStack(alignment: .leading, spacing: 4) {
                    fieldLabel(l10n.t(.timeoutLabel))
                    TextField(l10n.t(.timeoutPlaceholder), text: $timeoutText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                }
            }
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    /// Opens an NSOpenPanel to let the user pick a directory.
    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles         = false
        panel.canChooseDirectories   = true
        panel.allowsMultipleSelection = false
        panel.title = l10n.t(.chooseWorkingDirectory)
        panel.prompt = l10n.t(.choosePrompt)
        if !workingDirectory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: workingDirectory)
        }
        if panel.runModal() == .OK, let url = panel.url {
            workingDirectory = url.path
        }
    }

    private func populate() {
        if case .create = mode {
            workspaceId = defaultWorkspaceId
            return
        }
        guard case .edit(let action) = mode else { return }
        name              = action.name
        command           = action.command
        stopCommand       = action.stopCommand ?? ""
        shell             = action.shell
        workspaceId       = action.workspaceId
        usesShellProfile  = action.usesShellProfile
        workingDirectory  = action.workingDirectory ?? ""
        envText           = action.environment
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: "\n")
        timeoutText       = action.timeout.map { String(Int($0)) } ?? ""
    }

    private func saveAndDismiss() {
        let trimName    = name.trimmingCharacters(in: .whitespaces)
        let trimCwd     = workingDirectory.trimmingCharacters(in: .whitespaces)
        let trimStop    = stopCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        var action: Action
        switch mode {
        case .create:
            action = Action(name: trimName, command: command)
        case .edit(let existing):
            action         = existing
            action.name    = trimName
            action.command = command
        }

        action.shell            = shell
        action.stopCommand      = trimStop.isEmpty ? nil : trimStop
        action.workspaceId      = workspaceId
        action.usesShellProfile = usesShellProfile
        action.workingDirectory = trimCwd.isEmpty ? nil : trimCwd

        // Parse environment variables
        var env: [String: String] = [:]
        for line in envText.components(separatedBy: .newlines) {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            guard !stripped.isEmpty else { continue }
            let parts = stripped.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty { env[key] = val }
            }
        }
        action.environment = env

        let trimTimeout = timeoutText.trimmingCharacters(in: .whitespaces)
        action.timeout  = Double(trimTimeout).flatMap { $0 > 0 ? $0 : nil }

        onSave(action)
        dismiss()
    }
}

// MARK: - FormSection helper

/// A labelled card used to group related fields in the form.
private struct FormSection<Content: View>: View {
    let title:   String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title   = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .padding(.bottom, 12)
    }
}
