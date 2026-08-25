import Foundation

/// Loads the user's real shell environment (PATH, NVM_DIR, PYENV_ROOT, …) by
/// briefly spawning a login+interactive shell that prints its environment.
/// GUI apps launched from Finder/Dock inherit a minimal environment from
/// launchd, so tools installed via nvm, pyenv, Homebrew, etc. are otherwise
/// unreachable ("command not found").
///
/// The capture shell (`zsh -ilc '/usr/bin/env -0'`) is ONLY used to read
/// variables. Actual scripts keep running through the plain
/// `shell -c <command>` process tree, so real-time stdout/stderr, SIGTERM
/// and custom stop commands are completely unaffected.
final class ShellEnvironmentLoader {

    // MARK: - Markers

    /// Sentinel markers guard against stray output (echo, neofetch, fortune…)
    /// that user rc files may print: only data between the markers is parsed.
    private static let beginMarker = "__QUICKRUN_ENV_BEGIN__"
    private static let endMarker   = "__QUICKRUN_ENV_END__"

    /// How long to wait for the capture shell before giving up.
    private static let timeout: TimeInterval = 10

    // MARK: - Cache

    /// Cached raw shell environments, keyed by shell. Lives for the whole app
    /// run; invalidated when an action is saved (the user may have just edited
    /// their shell configuration).
    private static var cache: [Shell: [String: String]] = [:]
    private static let lock = NSLock()

    // MARK: - Public API

    /// Environment for running a script: the app's own environment overlaid
    /// with the user's shell environment (shell values win, so PATH etc. come
    /// from the login shell). Falls back to the app environment if the shell
    /// capture fails — the script is always allowed to run.
    static func environment(for shell: Shell) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if let shellEnvironment = shellEnvironment(for: shell) {
            for (key, value) in shellEnvironment { environment[key] = value }
        }
        return environment
    }

    /// Drops the cached environments so the next run reloads them.
    static func invalidateAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }

    /// Pre-warms the cache. Call from a background queue at app launch so the
    /// first script run doesn't pay the shell-startup cost.
    static func preload(shells: [Shell]) {
        for shell in shells {
            lock.lock()
            let cached = cache[shell] != nil
            lock.unlock()
            guard !cached else { continue }
            _ = shellEnvironment(for: shell)
        }
    }

    // MARK: - Loading

    /// Returns the raw environment captured from the shell (cached per shell).
    private static func shellEnvironment(for shell: Shell) -> [String: String]? {
        lock.lock()
        if let cached = cache[shell] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let loaded = capture(shell: shell)

        lock.lock()
        // Prefer an already-cached value if another call raced us.
        if let cached = cache[shell] {
            lock.unlock()
            return cached
        }
        if let loaded { cache[shell] = loaded }
        lock.unlock()
        return loaded
    }

    /// Runs `<shell> -ilc` and captures `/usr/bin/env -0` output between the
    /// sentinel markers.
    private static func capture(shell: Shell) -> [String: String]? {
        NSLog("[ShellEnv] Loading environment using %@", shell.executablePath)

        let command = "printf '\(beginMarker)\\0'; /usr/bin/env -0; printf '\(endMarker)\\0'"

        let process = Process()
        let stdout  = Pipe()
        process.executableURL  = URL(fileURLWithPath: shell.executablePath)
        process.arguments      = ["-ilc", command]
        process.standardOutput = stdout
        // Interactive shells may print warnings ("can't access tty", plugin
        // banners) on stderr — keep it away from parsing.
        process.standardError  = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            NSLog("[ShellEnv] Failed to launch %@: %@", shell.executablePath, error.localizedDescription)
            NSLog("[ShellEnv] Falling back to application environment")
            return nil
        }

        // Read stdout on a background queue so a hung rc file (e.g. an
        // oh-my-zsh update prompt) can be timed out instead of freezing.
        let done = DispatchSemaphore(value: 0)
        var collected = Data()
        DispatchQueue.global(qos: .userInitiated).async {
            collected = stdout.fileHandleForReading.readDataToEndOfFile()
            done.signal()
        }

        if done.wait(timeout: .now() + timeout) == .timedOut {
            NSLog("[ShellEnv] Timed out loading environment from %@", shell.executablePath)
            process.terminate()
            NSLog("[ShellEnv] Falling back to application environment")
            return nil
        }
        process.waitUntilExit()

        guard let environment = parse(collected) else {
            NSLog("[ShellEnv] Failed to parse environment from %@", shell.executablePath)
            NSLog("[ShellEnv] Falling back to application environment")
            return nil
        }

        // Deliberately log only the count — never dump values (tokens, keys…).
        NSLog("[ShellEnv] Environment loaded successfully (%d variables)", environment.count)
        return environment
    }

    // MARK: - Parsing

    /// Parses `env -0` output: NUL-separated KEY=VALUE pairs, each split on the
    /// FIRST "=" so values containing "=" stay intact.
    private static func parse(_ data: Data) -> [String: String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        let parts = text.split(separator: "\0", omittingEmptySubsequences: false)

        // rc output may be glued to the front of the begin marker (e.g. a
        // `printf` without trailing newline), hence hasSuffix / hasPrefix.
        guard let beginIndex = parts.firstIndex(where: { $0.hasSuffix(beginMarker) }),
              let endIndex   = parts[beginIndex...].firstIndex(where: { $0.hasPrefix(endMarker) }),
              endIndex > beginIndex
        else { return nil }

        var environment: [String: String] = [:]
        for item in parts[(beginIndex + 1)..<endIndex] {
            let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2, !pair[0].isEmpty else { continue }
            environment[String(pair[0])] = String(pair[1])
        }
        return environment.isEmpty ? nil : environment
    }
}
