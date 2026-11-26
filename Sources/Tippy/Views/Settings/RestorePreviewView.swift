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
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: "Restore a backup", identifier: "restore-preview") {
            Button("Cancel") { dismiss() }
                .buttonStyle(.pixel(.paper, size: 10, fill: false))
                .accessibilityIdentifier("restore-cancel-button")
        } trailing: {
            EmptyView()
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 6 * u) {
                    PixelSection(
                        title: nil,
                        footer: "Restoring replaces everything on this phone with the backup: your log, reflections, coins, decorations and pets. Nothing is merged, so restoring the same backup twice just replaces it again."
                    ) {
                        Grid(alignment: .leading, horizontalSpacing: 8 * u, verticalSpacing: 4 * u) {
                            GridRow {
                                Text("")
                                Text("THIS PHONE").pixelFont(.labelBold, 8)
                                Text("BACKUP").pixelFont(.labelBold, 8)
                            }
                            .foregroundStyle(PixelPalette.tealDark)
                            row("Days logged", \.daysLogged, id: "days")
                            GridRow {
                                Text("Dates")
                                Text(range(preview.current)).pixelFont(.body, 9)
                                Text(range(preview.backup)).pixelFont(.body, 9).accessibilityIdentifier("preview-backup-dates")
                            }
                            row("Drinks", \.drinks, id: "drinks")
                            row("Reflections", \.reflections, id: "reflections")
                            row("Coins", \.coins, id: "coins")
                            row("Decorations", \.decorations, id: "decorations")
                            row("Pets", \.pets, id: "pets")
                        }
                        .pixelFont(.body, 11)
                    }
                    Button("Replace everything on this phone") {
                        backup.apply(pending)
                        dismiss()
                    }
                    .buttonStyle(.pixel(.wood, size: 10))
                    .accessibilityIdentifier("restore-confirm-button")
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
            }
        }
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
