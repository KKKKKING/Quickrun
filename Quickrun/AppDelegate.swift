import AppKit
import SwiftUI

/// Manages the NSStatusItem (menu bar icon) and the NSPopover (panel).
/// Also owns the shared state objects so they outlive any individual view.
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {

    // Shared stores — injected into views as environment objects
    let actionStore    = ActionStore()
    let runStore       = RunStore()
    let workspaceStore = WorkspaceStore()
    let languageManager = LanguageManager()

    @Published var mainWindowOpenTrigger = 0

    private var statusItem: NSStatusItem!
    private var popover:    NSPopover!

    // Strong reference to our window delegate so it is never released.
    private let hideOnCloseDelegate = HideOnCloseDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        // Attach the hide-delegate as soon as the main window first appears.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(anyWindowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    /// Every time ANY titled window becomes key, hijack its delegate so the
    /// close button hides rather than destroys it. Safe to call multiple times
    /// — HideOnCloseDelegate is idempotent and does not break SwiftUI internals.
    @objc private func anyWindowBecameKey(_ note: Notification) {
        guard let window = note.object as? NSWindow,
              window.styleMask.contains(.titled) else { return }
        window.delegate = hideOnCloseDelegate
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        runStore.stopAll()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        if let img = NSImage(named: "QuickrunLogo") {
            img.size = NSSize(width: 18, height: 18)
            button.image = img
        }
        button.action = #selector(togglePanel)
        button.target = self
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Popover / Panel

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: PanelView(openMainWindow: { [weak self] in self?.openMainWindow() })
                .environmentObject(actionStore)
                .environmentObject(runStore)
                .environmentObject(workspaceStore)
                .environmentObject(languageManager)
        )
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
    }

    // MARK: - Main Window

    func openMainWindow(then notification: Notification.Name? = nil) {
        popover.performClose(nil)

        if let name = notification {
            NotificationCenter.default.post(name: name, object: nil)
        }

        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
                // Window exists (hidden by HideOnCloseDelegate or still visible).
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            } else {
                // First launch or window never created yet — let SwiftUI build it.
                NotificationCenter.default.post(name: .quickrunRequestOpenMainWindow, object: nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - HideOnCloseDelegate

/// Intercepts the red close button: hides the window instead of releasing it.
/// makeKeyAndOrderFront then reliably brings it back every time.
private class HideOnCloseDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false          // cancel the actual close / release
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let quickrunNavigateToRuns         = Notification.Name("quickrunNavigateToRuns")
    static let quickrunNavigateToActions      = Notification.Name("quickrunNavigateToActions")
    static let quickrunRequestOpenMainWindow   = Notification.Name("quickrunRequestOpenMainWindow")
}
