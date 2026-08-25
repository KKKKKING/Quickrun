import Foundation

/// Manages the lifecycle of a single script execution.
/// Creates a child process, wires stdout/stderr pipes, and handles termination.
final class ProcessRunner {
    private var process: Process?

    /// Called on the main thread with new output text (stdout + stderr).
    var onOutput: ((String) -> Void)?

    /// Called on the main thread when the process terminates.
    var onTermination: ((Int32, RunStatus) -> Void)?

    private(set) var isRunning = false

    /// Starts the process for the given action.
    /// - Throws: if the executable cannot be launched.
    func start(action: Action) throws {
        try start(
            command:          action.command,
            shell:            action.shell,
            usesShellProfile: action.usesShellProfile,
            workingDirectory: action.workingDirectory,
            environment:      action.environment
        )
    }

    /// Starts an arbitrary shell command (used for custom stop commands).
    /// - Throws: if the executable cannot be launched.
    func start(
        command: String,
        shell: Shell,
        usesShellProfile: Bool,
        workingDirectory: String?,
        environment: [String: String]
    ) throws {
        let proc = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        proc.executableURL = URL(fileURLWithPath: shell.executablePath)

        if usesShellProfile {
            switch shell {
            case .bash:
                // Non-interactive bash does NOT expand aliases by default and does NOT
                // source ~/.bashrc automatically (login shell only reads ~/.bash_profile).
                // Fix: enable alias expansion and source both files explicitly.
                let preamble = """
                shopt -s expand_aliases
                [[ -f ~/.bash_profile ]] && source ~/.bash_profile
                [[ -f ~/.bashrc ]]       && source ~/.bashrc
                """
                proc.arguments = ["-c", "\(preamble)\n\(command)"]
            case .zsh:
                // zsh login shell sources ~/.zprofile + ~/.zshrc automatically.
                // Also source ~/.bash_profile for tools that only write there.
                let preamble = "[[ -f ~/.bash_profile ]] && source ~/.bash_profile"
                proc.arguments = ["-l", "-c", "\(preamble)\n\(command)"]
            }
        } else {
            proc.arguments = ["-c", command]
        }

        if let cwd = workingDirectory, !cwd.isEmpty {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        // Inherit the current environment, then overlay action-specific vars
        var env = ProcessInfo.processInfo.environment
        for (key, val) in environment { env[key] = val }
        proc.environment = env

        proc.standardOutput = outputPipe
        proc.standardError  = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.onOutput?(text) }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            // Prefix stderr lines so they're distinguishable in the log view
            DispatchQueue.main.async { self?.onOutput?("[stderr] " + text) }
        }

        proc.terminationHandler = { [weak self] p in
            let code   = p.terminationStatus
            let status: RunStatus
            switch p.terminationReason {
            case .exit:           status = code == 0 ? .finished : .error
            case .uncaughtSignal: status = .killed
            @unknown default:     status = .error
            }
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.onTermination?(code, status)
            }
        }

        try proc.run()
        self.process = proc
        isRunning = true
    }

    /// Sends SIGTERM to the child process.
    func stop() {
        process?.terminate()
    }
}
