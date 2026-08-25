import SwiftUI

/// Listens for .quickrunRequestOpenMainWindow and exposes a counter so the App can
/// reliably re-render and call openWindow(id: "main") when the panel requests it.
private final class OpenMainWindowRequestListener: ObservableObject {
    @Published private(set) var requestCount = 0

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .quickrunRequestOpenMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.requestCount += 1
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}

@main
struct QuickrunApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var openMainWindowRequestListener = OpenMainWindowRequestListener()

    @AppStorage(SettingsKey.theme) private var theme: AppTheme = .system
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Quickrun", id: "main") {
            MainWindowView()
                .environmentObject(appDelegate.actionStore)
                .environmentObject(appDelegate.runStore)
                .environmentObject(appDelegate.workspaceStore)
                .environmentObject(appDelegate.languageManager)
                .preferredColorScheme(theme.colorScheme)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 860, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        // Reliable trigger from AppDelegate when no existing window is found (e.g. after user closed it).
        .onChange(of: openMainWindowRequestListener.requestCount) { _ in
            openWindow(id: "main")
        }
    }
}
