import Foundation
import SwiftUI

// MARK: - Workspace

/// A named group that actions can be assigned to.
struct Workspace: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var color: WorkspaceColor = .blue

    init(name: String, color: WorkspaceColor = .blue) {
        self.name  = name
        self.color = color
    }
}

enum WorkspaceColor: String, Codable, CaseIterable, Identifiable {
    case blue, green, orange, pink, purple, red, teal, yellow

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue:   return L10n.t(.colorBlue)
        case .green:  return L10n.t(.colorGreen)
        case .orange: return L10n.t(.colorOrange)
        case .pink:   return L10n.t(.colorPink)
        case .purple: return L10n.t(.colorPurple)
        case .red:    return L10n.t(.colorRed)
        case .teal:   return L10n.t(.colorTeal)
        case .yellow: return L10n.t(.colorYellow)
        }
    }

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .green:  return .green
        case .orange: return .orange
        case .pink:   return .pink
        case .purple: return .purple
        case .red:    return .red
        case .teal:   return .teal
        case .yellow: return .yellow
        }
    }
}

// MARK: - Shell

enum Shell: String, Codable, CaseIterable, Identifiable {
    case bash = "bash"
    case zsh  = "zsh"

    var id: String { rawValue }
    var label: String { rawValue }
    var executablePath: String { "/bin/\(rawValue)" }
}

// MARK: - Action

/// A user-defined task that wraps a shell script.
struct Action: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// Full shell script content — may be multiline.
    var command: String
    /// Optional script executed when the action is stopped.
    /// nil/empty = simply send SIGTERM to the running process.
    var stopCommand: String? = nil
    /// Shell used to execute the command.
    var shell: Shell = .bash
    /// Optional workspace this action belongs to.
    var workspaceId: UUID?
    /// If true, the shell is launched as a login shell so that
    /// the user's profile is sourced before execution.
    var usesShellProfile: Bool = false
    /// Optional folder chosen via the directory picker; nil = inherit app cwd.
    var workingDirectory: String?
    var environment: [String: String] = [:]
    var timeout: TimeInterval?          // seconds; nil means no timeout

    init(
        name: String,
        command: String,
        stopCommand: String? = nil,
        workspaceId: UUID? = nil,
        usesShellProfile: Bool = false,
        workingDirectory: String? = nil,
        environment: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) {
        self.name             = name
        self.command          = command
        self.stopCommand      = stopCommand
        self.workspaceId      = workspaceId
        self.usesShellProfile = usesShellProfile
        self.workingDirectory = workingDirectory
        self.environment      = environment
        self.timeout          = timeout
    }
}

// MARK: - Trash

/// An action that has been soft-deleted — can be restored or permanently removed.
struct TrashedAction: Identifiable, Codable {
    var id: UUID { action.id }
    var action:    Action
    var trashedAt: Date
}

// MARK: - Run

/// Lifecycle state of a single script execution.
enum RunStatus: String, Codable {
    case running
    case finished
    case error
    case killed

    var label: String {
        switch self {
        case .running:  return L10n.t(.statusRunning)
        case .finished: return L10n.t(.statusFinished)
        case .error:    return L10n.t(.statusError)
        case .killed:   return L10n.t(.statusKilled)
        }
    }

    var color: Color {
        switch self {
        case .running:  return .green
        case .finished: return .secondary
        case .error:    return .orange
        case .killed:   return .red
        }
    }
}

/// A single execution of an action.
struct Run: Identifiable {
    let id: UUID = UUID()
    let actionId: UUID
    let actionName: String
    let startedAt: Date
    var status: RunStatus
    var exitCode: Int32?
}
