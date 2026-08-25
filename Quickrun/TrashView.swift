import SwiftUI

/// Dedicated tab showing trashed actions that can be restored or permanently deleted.
struct TrashView: View {
    @EnvironmentObject var actionStore: ActionStore
    @EnvironmentObject var l10n:        LanguageManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l10n.t(.tabTrash)).font(.title2).bold()
                Spacer()
                if !actionStore.trashedActions.isEmpty {
                    Button(l10n.t(.emptyTrash)) { actionStore.emptyTrash() }
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                }
            }
            .padding([.horizontal, .top], 20)
            .padding(.bottom, 12)

            Divider()

            if actionStore.trashedActions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(l10n.t(.trashEmptyTitle)).font(.title3).bold()
                    Text(l10n.t(.trashEmptyHint))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(actionStore.trashedActions) { trashed in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(trashed.action.name).font(.headline).lineLimit(1)
                                Text(trashed.action.command
                                        .components(separatedBy: .newlines).first
                                        ?? trashed.action.command)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(l10n.f(.deletedLabel, trashed.trashedAt.shortLabel))
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Button(l10n.t(.restore)) { actionStore.restore(trashed) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            Button { actionStore.permanentlyDelete(trashed) } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help(l10n.t(.deletePermanently))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
