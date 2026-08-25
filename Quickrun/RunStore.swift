import Foundation
import Combine

/// Manages run lifecycle and keeps the in-memory run history.
/// At most one run per action is active at a time (mono-instance).
final class RunStore: ObservableObject {
    @Published var runs: [Run] = []

    /// Accumulated log text per run (run.id → full output string).
    private(set) var logs: [UUID: String] = [:]

    private var runners:      [UUID: ProcessRunner] = [:]  // run.id  → runner
    private var stoppers:     [UUID: ProcessRunner] = [:]  // run.id  → stop-command runner
    private var activeRunIds: [UUID: UUID]           = [:]  // action.id → run.id

    // MARK: - Public API

    func isRunning(actionId: UUID) -> Bool {
        activeRunIds[actionId] != nil
    }

    func log(for runId: UUID) -> String {
        logs[runId] ?? ""
    }

    /// Start the action if idle, stop it if currently running.
    func toggle(action: Action) {
        if let runId = activeRunIds[action.id] {
            stop(action: action, runId: runId)
        } else {
            launch(action: action)
        }
    }

    /// Start every idle action in the list (workspace "start all").
    func startAll(actions: [Action]) {
        actions.filter { !isRunning(actionId: $0.id) }.forEach { launch(action: $0) }
    }

    /// Stop every running action in the list (workspace "stop all").
    /// Each action's custom stop command is honored.
    func stopAll(actions: [Action]) {
        for action in actions {
            if let runId = activeRunIds[action.id] {
                stop(action: action, runId: runId)
            }
        }
    }

    /// Terminate all running processes (call on app quit).
    func stopAll() {
        runners.values.forEach { $0.stop() }
    }

    /// Remove all non-running runs from the history.
    func clearFinished() {
        runs.removeAll { $0.status != .running }
    }

    // MARK: - Private

    /// Stop a run: execute the action's custom stop command when configured,
    /// otherwise fall back to SIGTERM. If the stop command returns and the main
    /// process is still alive, SIGTERM is sent as a safety net.
    private func stop(action: Action, runId: UUID) {
        guard let runner = runners[runId] else { return }
        // A stop command is already in flight for this run — ignore.
        guard stoppers[runId] == nil else { return }

        let stopCommand = action.stopCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !stopCommand.isEmpty else {
            runner.stop()
            return
        }

        appendLog(runId: runId, text: "\n[stop] \(stopCommand)\n")

        let stopper = ProcessRunner()
        stoppers[runId] = stopper

        stopper.onOutput = { [weak self] text in
            self?.appendLog(runId: runId, text: "[stop] \(text)")
        }
        stopper.onTermination = { [weak self, weak runner] code, _ in
            guard let self else { return }
            self.appendLog(runId: runId, text: "[stop] exited with code \(code)\n")
            self.stoppers.removeValue(forKey: runId)
            // Safety net: the stop command did not end the main process.
            if let runner, runner.isRunning { runner.stop() }
        }

        do {
            try stopper.start(
                command:          stopCommand,
                shell:            action.shell,
                usesShellProfile: action.usesShellProfile,
                workingDirectory: action.workingDirectory,
                environment:      action.environment
            )
        } catch {
            stoppers.removeValue(forKey: runId)
            appendLog(runId: runId, text: "[stop] launch error: \(error.localizedDescription)\n")
            runner.stop()
            return
        }

        // Last resort: never let a hung stop command keep the run alive forever.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak stopper, weak runner] in
            if stopper?.isRunning == true { stopper?.stop() }
            if runner?.isRunning == true { runner?.stop() }
        }
    }

    private func appendLog(runId: UUID, text: String) {
        // Manually trigger objectWillChange because dictionary mutations
        // are not automatically detected by @Published.
        objectWillChange.send()
        logs[runId, default: ""] += text
    }
    private func launch(action: Action) {
        let run = Run(
            actionId:   action.id,
            actionName: action.name,
            startedAt:  Date(),
            status:     .running
        )
        let runId = run.id

        runs.insert(run, at: 0)
        logs[runId]          = ""
        activeRunIds[action.id] = runId

        let runner = ProcessRunner()
        runners[runId] = runner

        runner.onOutput = { [weak self] text in
            self?.appendLog(runId: runId, text: text)
        }

        runner.onTermination = { [weak self] code, status in
            guard let self else { return }
            if let idx = self.runs.firstIndex(where: { $0.id == runId }) {
                self.runs[idx].status   = status
                self.runs[idx].exitCode = code
            }
            self.runners.removeValue(forKey: runId)
            self.activeRunIds.removeValue(forKey: action.id)
        }

        do {
            try runner.start(action: action)
        } catch {
            if let idx = runs.firstIndex(where: { $0.id == runId }) {
                runs[idx].status = .error
            }
            runners.removeValue(forKey: runId)
            activeRunIds.removeValue(forKey: action.id)
            objectWillChange.send()
            logs[runId, default: ""] += "Launch error: \(error.localizedDescription)\n"
        }
    }
}
