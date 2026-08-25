import SwiftUI

/// Terminal-like area that displays the stdout/stderr output of a run.
struct LogsView: View {
    let runId: UUID?

    @EnvironmentObject var runStore: RunStore
    @EnvironmentObject var l10n:     LanguageManager

    private var logText: String {
        guard let id = runId else { return "" }
        return runStore.log(for: id)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                Text(logText.isEmpty ? l10n.t(.noOutputYet) : logText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(logText.isEmpty ? Color.secondary : Color.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .id("logBottom")
            }
            .background(Color(NSColor.textBackgroundColor))
            // Auto-scroll to bottom when new output arrives
            .onChange(of: logText) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("logBottom", anchor: .bottom)
                }
            }
        }
    }
}
