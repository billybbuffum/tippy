import SwiftUI
import TippyBackup
import TippyModeration

/// Before a restore: this phone and the backup side by side, so she knows
/// exactly what would be replaced. Nothing changes until she confirms.
struct RestorePreviewView: View {
    let pending: BackupModel.PendingRestore

    @Environment(BackupModel.self) private var backup
    @Environment(JournalModel.self) private var journal
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                            Text("")
                            Text("This phone").font(.caption.weight(.semibold))
                            Text("Backup").font(.caption.weight(.semibold))
                        }
                        row("Days logged", \.daysLogged, id: "days")
                        GridRow {
                            Text("Dates")
                            Text(range(preview.current)).font(.caption)
                            Text(range(preview.backup)).font(.caption).accessibilityIdentifier("preview-backup-dates")
                        }
                        row("Drinks", \.drinks, id: "drinks")
                        row("Reflections", \.reflections, id: "reflections")
                        row("Coins", \.coins, id: "coins")
                        row("Decorations", \.decorations, id: "decorations")
                        row("Pets", \.pets, id: "pets")
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                } footer: {
                    Text("Restoring replaces everything on this phone with the backup: your log, reflections, coins, decorations and pets. Nothing is merged, so restoring the same backup twice just replaces it again.")
                }
                Section {
                    Button(role: .destructive) {
                        backup.apply(pending)
                        dismiss()
                    } label: {
                        Text("Replace everything on this phone").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("restore-confirm-button")
                }
            }
            .navigationTitle("Restore a backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("restore-cancel-button")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("restore-preview")
    }

    private var preview: RestorePreview { pending.preview }

    private func row(_ title: String, _ value: KeyPath<RestorePreview.Side, Int>, id: String) -> some View {
        GridRow {
            Text(title)
            Text("\(preview.current[keyPath: value])")
                .accessibilityIdentifier("preview-current-\(id)")
            Text("\(preview.backup[keyPath: value])")
                .accessibilityIdentifier("preview-backup-\(id)")
        }
    }

    private func range(_ side: RestorePreview.Side) -> String {
        guard let first = side.firstDay, let last = side.lastDay else { return "—" }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(journal.date(of: first).formatted(style))–\(journal.date(of: last).formatted(style))"
    }
}
