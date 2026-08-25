import Foundation

// MARK: - Language

/// UI language. `.system` resolves from the macOS preferred languages.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, chinese

    var id: String { rawValue }

    /// Display name shown in the language picker.
    var displayName: String {
        switch self {
        case .system:  return L10n.t(.languageSystem)
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// Whether UI strings should be rendered in Chinese.
    var isChinese: Bool {
        switch self {
        case .chinese: return true
        case .english: return false
        case .system:  return Locale.preferredLanguages.first?.hasPrefix("zh") == true
        }
    }
}

// MARK: - Language manager

/// Observable language setting shared by every view through the environment.
/// Any view holding this object re-renders automatically when the language changes.
final class LanguageManager: ObservableObject {
    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: SettingsKey.language) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.language) ?? ""
        self.language = AppLanguage(rawValue: raw) ?? .system
    }

    /// Simple lookup.
    func t(_ key: L10nKey) -> String { L10n.string(key, chinese: language.isChinese) }

    /// Formatted lookup (String(format:) semantics).
    func f(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    /// "1 run" / "3 runs" / "3 次运行"
    func runsCount(_ count: Int) -> String {
        if language.isChinese { return "\(count) 次运行" }
        return count == 1 ? "1 run" : "\(count) runs"
    }

    /// "1 action" / "3 actions" / "3 个操作"
    func actionsCount(_ count: Int) -> String {
        if language.isChinese { return "\(count) 个操作" }
        return count == 1 ? "1 action" : "\(count) actions"
    }
}

// MARK: - String catalog

enum L10nKey {
    // Common
    case cancel, save, delete, edit, done, clear, all, none, quit

    // Run status
    case statusRunning, statusFinished, statusError, statusKilled, statusIdle

    // Main window tabs
    case tabWorkspaces, tabActions, tabRuns, tabTrash, tabSettings
    case quitQuickrun, quitConfirm, quitMessageNoRuns, quitMessageRunning

    // Settings
    case appearance, theme, themeLight, themeDark, themeSystem
    case language, languageSystem
    case startup, launchAtLogin
    case menuBarPanel, panelStyle, panelStyleCards, panelStyleList, panelShowLogs
    case dataSection, exportLabel, exportButton, importLabel, importButton, importHint
    case resetLabel, resetButton, about, aboutNote
    case exportPanelTitle, importPanelTitle
    case errorEncoding, errorWriteFile, errorInvalidFile
    case importConfirmTitle, importReplace, importSummary
    case resetTitle, resetMessage, resetTypeHint

    // Menu bar panel
    case openApp, noActionsYet, noActionsInWorkspace, logs, seeAll, noRunsYet, noOutput
    case runAction, stopAction, startAll, stopAll, runningCount

    // Actions view
    case newAction, noActions, noActionsHint, noWorkspaceActionsHint
    case deleteActionTitle, moveToTrash, trashMessage
    case deleteActionHelp, neverRun, lastRun, stop, run, editActionHelp, viewLogsHelp
    case logsFor, noRunsForAction

    // Action form
    case editActionTitle, actionSection, nameLabel, namePlaceholder, workspaceLabel
    case scriptSection, contentLabel, contentHint, shellLabel
    case loadShellProfile, shellProfileHint
    case stopCommandLabel, stopCommandHint
    case portLabel
    case optionsSection, workingDirectory, workingDirectoryPlaceholder, chooseFolder, clearHint
    case envVars, envHint, timeoutLabel, timeoutPlaceholder
    case chooseWorkingDirectory, choosePrompt

    // Workspaces
    case newWorkspace, noWorkspaces, noWorkspacesHint
    case deleteWorkspaceTitle, deleteWorkspaceEmpty, deleteWorkspaceNonEmpty
    case editWorkspaceTitle, colorLabel
    case colorBlue, colorGreen, colorOrange, colorPink, colorPurple, colorRed, colorTeal, colorYellow

    // Runs
    case runsTitle, noRunsTitle, noRunsHint, selectRunHint

    // Trash
    case emptyTrash, trashEmptyTitle, trashEmptyHint, deletedLabel, restore, deletePermanently

    // Logs
    case noOutputYet

    // Dates
    case yesterdayAt
}

/// Static catalog — reads the persisted language straight from UserDefaults so it
/// can be used outside of views (models, value types). Views should prefer the
/// `LanguageManager` environment object so they re-render on language change.
enum L10n {
    static var isChinese: Bool {
        let raw = UserDefaults.standard.string(forKey: SettingsKey.language) ?? ""
        return (AppLanguage(rawValue: raw) ?? .system).isChinese
    }

    static func t(_ key: L10nKey) -> String { string(key, chinese: isChinese) }

    static func f(_ key: L10nKey, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    static func string(_ key: L10nKey, chinese: Bool) -> String {
        let table = chinese ? zh : en
        return table[key] ?? en[key] ?? ""
    }

    // MARK: English

    private static let en: [L10nKey: String] = [
        // Common
        .cancel: "Cancel", .save: "Save", .delete: "Delete", .edit: "Edit",
        .done: "Done", .clear: "Clear", .all: "All", .none: "None", .quit: "Quit",

        // Run status
        .statusRunning: "Running", .statusFinished: "Finished",
        .statusError: "Error", .statusKilled: "Killed", .statusIdle: "Idle",

        // Tabs & main window
        .tabWorkspaces: "Workspaces", .tabActions: "Actions",
        .tabRuns: "Runs & Logs", .tabTrash: "Trash", .tabSettings: "Settings",
        .quitQuickrun: "Quit Quickrun",
        .quitConfirm: "Quit Quickrun?",
        .quitMessageNoRuns: "The app will close.",
        .quitMessageRunning: "All running scripts will be stopped before closing.",

        // Settings
        .appearance: "Appearance", .theme: "Theme",
        .themeLight: "Light", .themeDark: "Dark", .themeSystem: "System",
        .language: "Language", .languageSystem: "System",
        .startup: "Startup", .launchAtLogin: "Launch at login",
        .menuBarPanel: "Menu Bar Panel", .panelStyle: "Panel style",
        .panelStyleCards: "Cards", .panelStyleList: "List",
        .panelShowLogs: "Show logs in panel",
        .dataSection: "Data", .exportLabel: "Export", .exportButton: "Export configuration…",
        .importLabel: "Import", .importButton: "Import configuration…",
        .importHint: "Import replaces all existing actions and workspaces.",
        .resetLabel: "Reset", .resetButton: "Reset all data…",
        .about: "About",
        .aboutNote: "Scripts run with your user privileges. Quickrun is not sandboxed.",
        .exportPanelTitle: "Export Quickrun configuration",
        .importPanelTitle: "Import Quickrun configuration",
        .errorEncoding: "Encoding error.",
        .errorWriteFile: "Could not write file: %@",
        .errorInvalidFile: "Invalid or incompatible file.",
        .importConfirmTitle: "Replace current configuration?",
        .importReplace: "Import and replace",
        .importSummary: "%lld action(s) and %lld workspace(s) will replace the current configuration.",
        .resetTitle: "Full reset",
        .resetMessage: "All actions, workspaces and the trash will be **permanently deleted**. This cannot be undone.",
        .resetTypeHint: "Type **%@** to confirm:",

        // Menu bar panel
        .openApp: "Open App",
        .noActionsYet: "No actions yet.\nOpen Quickrun to add one.",
        .noActionsInWorkspace: "No actions in this workspace.",
        .logs: "Logs", .seeAll: "See all", .noRunsYet: "No runs yet.",
        .noOutput: "(no output)",
        .runAction: "Run %@", .stopAction: "Stop %@",
        .startAll: "Start All", .stopAll: "Stop All",
        .runningCount: "%lld/%lld running",

        // Actions view
        .newAction: "New Action",
        .noActions: "No Actions",
        .noActionsHint: "Tap \"New Action\" to add a script or command.",
        .noWorkspaceActionsHint: "Switch filter or create an action in this workspace.",
        .deleteActionTitle: "Delete \"%@\"?",
        .moveToTrash: "Move to Trash",
        .trashMessage: "The action will be moved to the trash. You can restore it later.",
        .deleteActionHelp: "Delete action",
        .neverRun: "Never run",
        .lastRun: "Last run %@ — %@",
        .stop: "Stop", .run: "Run",
        .editActionHelp: "Edit action", .viewLogsHelp: "View logs",
        .logsFor: "Logs — %@",
        .noRunsForAction: "No runs yet for this action.",

        // Action form
        .editActionTitle: "Edit Action",
        .actionSection: "Action",
        .nameLabel: "Name", .namePlaceholder: "e.g. Start dev server",
        .workspaceLabel: "Workspace",
        .scriptSection: "Script", .contentLabel: "Content",
        .contentHint: "Full shell script — supports shebang, functions, multiline pipelines, etc.",
        .shellLabel: "Shell",
        .loadShellProfile: "Load shell environment",
        .shellProfileHint: "Loads your login shell environment (PATH, Node, Python, Homebrew, nvm, pyenv, …) before running the script.",
        .stopCommandLabel: "Stop command (optional)",
        .stopCommandHint: "Executed when the action is stopped. Leave empty to simply send SIGTERM to the process.",
        .portLabel: "Port (optional)",
        .optionsSection: "Options",
        .workingDirectory: "Working directory",
        .workingDirectoryPlaceholder: "Default (inherits app directory)",
        .chooseFolder: "Choose folder…", .clearHint: "Clear",
        .envVars: "Environment variables", .envHint: "One KEY=VALUE per line.",
        .timeoutLabel: "Timeout (seconds)", .timeoutPlaceholder: "Empty = no timeout",
        .chooseWorkingDirectory: "Choose Working Directory", .choosePrompt: "Choose",

        // Workspaces
        .newWorkspace: "New Workspace",
        .noWorkspaces: "No Workspaces",
        .noWorkspacesHint: "Group your actions into workspaces for quick filtering.",
        .deleteWorkspaceTitle: "Delete \"%@\"?",
        .deleteWorkspaceEmpty: "This workspace will be permanently deleted.",
        .deleteWorkspaceNonEmpty: "This workspace contains %lld action(s). They will be unassigned from it.",
        .editWorkspaceTitle: "Edit Workspace",
        .colorLabel: "Color",
        .colorBlue: "Blue", .colorGreen: "Green", .colorOrange: "Orange",
        .colorPink: "Pink", .colorPurple: "Purple", .colorRed: "Red",
        .colorTeal: "Teal", .colorYellow: "Yellow",

        // Runs
        .runsTitle: "Runs", .noRunsTitle: "No Runs Yet",
        .noRunsHint: "Run an action to see its history here.",
        .selectRunHint: "Select a run to view its logs",

        // Trash
        .emptyTrash: "Empty Trash",
        .trashEmptyTitle: "Trash is Empty",
        .trashEmptyHint: "Deleted actions will appear here.",
        .deletedLabel: "Deleted %@",
        .restore: "Restore", .deletePermanently: "Delete permanently",

        // Logs
        .noOutputYet: "No output yet.",

        // Dates
        .yesterdayAt: "Yesterday at %@",
    ]

    // MARK: 中文

    private static let zh: [L10nKey: String] = [
        // Common
        .cancel: "取消", .save: "保存", .delete: "删除", .edit: "编辑",
        .done: "完成", .clear: "清除", .all: "全部", .none: "无", .quit: "退出",

        // Run status
        .statusRunning: "运行中", .statusFinished: "已完成",
        .statusError: "错误", .statusKilled: "已终止", .statusIdle: "空闲",

        // Tabs & main window
        .tabWorkspaces: "分组", .tabActions: "操作",
        .tabRuns: "运行与日志", .tabTrash: "回收站", .tabSettings: "设置",
        .quitQuickrun: "退出 Quickrun",
        .quitConfirm: "退出 Quickrun？",
        .quitMessageNoRuns: "应用将关闭。",
        .quitMessageRunning: "关闭前将停止所有正在运行的脚本。",

        // Settings
        .appearance: "外观", .theme: "主题",
        .themeLight: "浅色", .themeDark: "深色", .themeSystem: "跟随系统",
        .language: "语言", .languageSystem: "跟随系统",
        .startup: "启动", .launchAtLogin: "登录时启动",
        .menuBarPanel: "菜单栏面板", .panelStyle: "展示方式",
        .panelStyleCards: "卡片", .panelStyleList: "列表",
        .panelShowLogs: "在面板中显示日志",
        .dataSection: "数据", .exportLabel: "导出", .exportButton: "导出配置…",
        .importLabel: "导入", .importButton: "导入配置…",
        .importHint: "导入将替换所有现有的操作和分组。",
        .resetLabel: "重置", .resetButton: "重置所有数据…",
        .about: "关于",
        .aboutNote: "脚本将以你的用户权限运行，Quickrun 未沙盒化。",
        .exportPanelTitle: "导出 Quickrun 配置",
        .importPanelTitle: "导入 Quickrun 配置",
        .errorEncoding: "编码错误。",
        .errorWriteFile: "无法写入文件：%@",
        .errorInvalidFile: "文件无效或不兼容。",
        .importConfirmTitle: "替换当前配置？",
        .importReplace: "导入并替换",
        .importSummary: "将导入 %lld 个操作和 %lld 个分组，并替换当前配置。",
        .resetTitle: "完全重置",
        .resetMessage: "所有操作、分组和回收站都将被**永久删除**，此操作无法撤销。",
        .resetTypeHint: "输入 **%@** 以确认：",

        // Menu bar panel
        .openApp: "打开应用",
        .noActionsYet: "还没有操作。\n打开 Quickrun 添加一个。",
        .noActionsInWorkspace: "该分组下没有操作。",
        .logs: "日志", .seeAll: "查看全部", .noRunsYet: "暂无运行记录。",
        .noOutput: "(无输出)",
        .runAction: "运行 %@", .stopAction: "停止 %@",
        .startAll: "全部启动", .stopAll: "全部停止",
        .runningCount: "运行中 %lld/%lld",

        // Actions view
        .newAction: "新建操作",
        .noActions: "暂无操作",
        .noActionsHint: "点击“新建操作”添加脚本或命令。",
        .noWorkspaceActionsHint: "切换筛选，或在该分组中创建一个操作。",
        .deleteActionTitle: "删除“%@”？",
        .moveToTrash: "移到回收站",
        .trashMessage: "该操作将被移到回收站，之后可以恢复。",
        .deleteActionHelp: "删除操作",
        .neverRun: "从未运行",
        .lastRun: "上次运行 %@ — %@",
        .stop: "停止", .run: "运行",
        .editActionHelp: "编辑操作", .viewLogsHelp: "查看日志",
        .logsFor: "日志 — %@",
        .noRunsForAction: "该操作还没有运行记录。",

        // Action form
        .editActionTitle: "编辑操作",
        .actionSection: "操作",
        .nameLabel: "名称", .namePlaceholder: "例如：启动开发服务器",
        .workspaceLabel: "分组",
        .scriptSection: "脚本", .contentLabel: "内容",
        .contentHint: "完整的 Shell 脚本 —— 支持 shebang、函数、多行管道等。",
        .shellLabel: "Shell",
        .loadShellProfile: "加载 Shell 环境",
        .shellProfileHint: "运行脚本前继承登录 Shell 环境（PATH、Node、Python、Homebrew、nvm、pyenv 等）。",
        .stopCommandLabel: "停止命令（可选）",
        .stopCommandHint: "点击停止时执行该命令。留空则直接向进程发送 SIGTERM 信号。",
        .portLabel: "端口（可选）",
        .optionsSection: "选项",
        .workingDirectory: "工作目录",
        .workingDirectoryPlaceholder: "默认（继承应用目录）",
        .chooseFolder: "选择文件夹…", .clearHint: "清除",
        .envVars: "环境变量", .envHint: "每行一个 KEY=VALUE。",
        .timeoutLabel: "超时（秒）", .timeoutPlaceholder: "留空 = 不限制",
        .chooseWorkingDirectory: "选择工作目录", .choosePrompt: "选择",

        // Workspaces
        .newWorkspace: "新建分组",
        .noWorkspaces: "暂无分组",
        .noWorkspacesHint: "将操作按分组归类，便于快速筛选和批量启动。",
        .deleteWorkspaceTitle: "删除“%@”？",
        .deleteWorkspaceEmpty: "该分组将被永久删除。",
        .deleteWorkspaceNonEmpty: "该分组包含 %lld 个操作，删除后这些操作将被移出分组。",
        .editWorkspaceTitle: "编辑分组",
        .colorLabel: "颜色",
        .colorBlue: "蓝色", .colorGreen: "绿色", .colorOrange: "橙色",
        .colorPink: "粉色", .colorPurple: "紫色", .colorRed: "红色",
        .colorTeal: "青色", .colorYellow: "黄色",

        // Runs
        .runsTitle: "运行记录", .noRunsTitle: "暂无运行记录",
        .noRunsHint: "运行一个操作后，这里会显示历史记录。",
        .selectRunHint: "选择一个运行记录查看日志",

        // Trash
        .emptyTrash: "清空回收站",
        .trashEmptyTitle: "回收站为空",
        .trashEmptyHint: "删除的操作会显示在这里。",
        .deletedLabel: "删除于 %@",
        .restore: "恢复", .deletePermanently: "永久删除",

        // Logs
        .noOutputYet: "暂无输出。",

        // Dates
        .yesterdayAt: "昨天 %@",
    ]
}
