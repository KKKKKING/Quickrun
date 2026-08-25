import SwiftUI

// AppSettings is NOT an ObservableObject — using @AppStorage inside ObservableObject
// causes "Publishing changes from within view updates" warnings because @AppStorage
// fires objectWillChange synchronously during the render cycle.
// Instead, each view declares its own @AppStorage properties directly.

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light:  return L10n.t(.themeLight)
        case .dark:   return L10n.t(.themeDark)
        case .system: return L10n.t(.themeSystem)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return nil
        }
    }
}

// MARK: - Menu bar panel style

/// How the menu bar panel renders the action list.
enum PanelStyle: String, CaseIterable, Identifiable {
    case cards, list

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cards: return L10n.t(.panelStyleCards)
        case .list:  return L10n.t(.panelStyleList)
        }
    }
}

// UserDefaults key constants
enum SettingsKey {
    static let theme          = "theme"
    static let launchAtLogin  = "launchAtLogin"
    static let panelStyle     = "panelStyle"
    static let panelShowLogs  = "panelShowLogs"
    static let language       = "appLanguage"
}

// MARK: - Date formatting

extension Date {
    /// Static label that never triggers a SwiftUI timer:
    /// "2:30 PM" if today, "Dec 15 at 2:30 PM" otherwise.
    var shortLabel: String {
        if Calendar.current.isDateInToday(self) {
            return formatted(.dateTime.hour().minute())
        }
        if Calendar.current.isDateInYesterday(self) {
            return L10n.f(.yesterdayAt, formatted(.dateTime.hour().minute()))
        }
        return formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
