import SwiftUI
import UniformTypeIdentifiers
import TippyModeration
import TippyWander

struct SettingsView: View {
    @Environment(JournalModel.self) private var model
    @Environment(WanderModel.self) private var wander
    @Environment(\.dismiss) private var dismiss
    @State private var petName = ""
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingRestore: BackupModel.PendingRestore?
    @Environment(BackupModel.self) private var backup

    var body: some View {
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: "Settings", identifier: "settings-sheet") {
            EmptyView()
        } trailing: {
            Button("Done") { dismiss() }
                .buttonStyle(.pixel(.teal, size: 10, fill: false))
                .accessibilityIdentifier("settings-done-button")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 6 * u) {
                    PixelSection(title: "Your pet") {
                        TextField("Name", text: $petName)
                            .accessibilityIdentifier("pet-name-field")
                            .pixelField()
                            .onAppear { petName = wander.shownPet?.name ?? model.settings.petName }
                            .onChange(of: petName) { rename(to: petName) }
                    }
                    goal
                    PixelSection(title: "Reminder") {
                        Toggle("Daily reminder", isOn: remindersBinding)
                            .toggleStyle(.pixel)
                            .accessibilityIdentifier("reminder-toggle")
                        if model.settings.reminderEnabled {
                            DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                                .pixelFont(.body, 11)
                                .accessibilityIdentifier("reminder-time-picker")
                        }
                    }
                    backupSection
                    about
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
            }
        }
        .task(id: model.journal) {
            exportURL = try? backup.export()
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { pendingRestore = backup.prepareRestore(from: data) }
        }
        .sheet(item: $pendingRestore) { pending in
            RestorePreviewView(pending: pending)
        }
    }

    private var goal: some View {
        PixelSection(
            title: "Goal",
            footer: "Counted in US standard drinks (14 g of alcohol). A new goal applies from this week on; past weeks keep theirs."
        ) {
            PixelStepper(name: "Weekly goal", text: "Weekly goal: \(Int(model.currentGoal)) drinks", value: goalBinding, range: 0...70, step: 1)
                .accessibilityIdentifier("weekly-goal-stepper")
            PixelStepper(name: "Before Tippy", text: "Before Tippy: \(Int(model.settings.baselinePerWeek)) a week", value: setting(\.baselinePerWeek), range: 0...150, step: 1)
                .accessibilityIdentifier("baseline-stepper")
            Toggle("Track what drinks cost", isOn: costTracked)
                .toggleStyle(.pixel)
                .accessibilityIdentifier("cost-toggle")
            if let cost = model.settings.costPerDrink {
                PixelStepper(name: "Cost per drink", text: "Cost per drink: \(cost.formatted(.currency(code: currencyCode)))", value: costBinding, range: 0...100, step: 0.5)
                    .accessibilityIdentifier("cost-stepper")
            }
            VStack(alignment: .leading, spacing: 2 * PixelGrid.uiPoint) {
                Text("Weeks start on")
                    .pixelFont(.body, 11)
                PixelSegmented(options: [2, 1], selection: setting(\.firstWeekday)) { $0 == 2 ? "Monday" : "Sunday" }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("week-start-picker")
        }
    }

    private var backupSection: some View {
        let u = PixelGrid.uiPoint
        return PixelSection(
            title: "Backup",
            footer: "Everything stays on this phone. Export a backup now and then (to Files or iCloud Drive) so a lost phone doesn't lose your history. A backup holds your log, coins, decorations and pets."
        ) {
            if let exportURL {
                ShareLink(item: exportURL) {
                    Text("Export a backup")
                }
                .buttonStyle(.pixel(.teal, size: 10))
                .accessibilityIdentifier("export-backup-button")
            }
            Text("Backups include your notes and reflections. Keep them somewhere private.")
                .pixelFont(.body, 9)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("export-privacy-note")
            Button("Restore from a backup") { importing = true }
                .buttonStyle(.pixel(.wood, size: 10))
                .accessibilityIdentifier("import-backup-button")
            if UISmokeMode.isActive {
                // XCUITest can't drive the system file picker reliably.
                Button("Use demo backup") {
                    if let data = UISmokeMode.demoBackup() { pendingRestore = backup.prepareRestore(from: data) }
                }
                .buttonStyle(.pixel(.paper, size: 10))
                .accessibilityIdentifier("restore-demo-button")
            }
            if let restoredAt = backup.restoredAt {
                HStack(spacing: 2 * u) {
                    PixelIcon.check
                    Text("Backup restored at \(restoredAt.formatted(date: .omitted, time: .shortened))")
                        .pixelFont(.body, 10)
                        .foregroundStyle(PixelPalette.leafDark)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("restore-done-label")
            }
        }
    }

    private var about: some View {
        PixelSection(title: "About") {
            Text("Tippy is not medical advice. If you drink heavily every day, talk to a doctor before cutting back: stopping suddenly can be dangerous.")
                .pixelFont(.body, 10)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: URL(string: "tel:18006624357")!) {
                Text("SAMHSA helpline: 1-800-662-4357")
            }
            .buttonStyle(.pixel(.paper, size: 10))
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
            }
            .pixelFont(.body, 10)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("build-number-label")
        }
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<ModerationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    /// Renames the active pet (its name lives in the Wander) and keeps the
    /// journal's pet name, which the reminders use and the starter egg
    /// hatches with, the same. An emptied field changes nothing yet.
    private func rename(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let pet = wander.shownPet, pet.name != trimmed { wander.name(pet.id, trimmed) }
        if model.settings.petName != trimmed { model.updateSettings { $0.petName = trimmed } }
    }

    private var goalBinding: Binding<Double> {
        Binding(get: { model.currentGoal }, set: { model.setWeeklyGoal($0) })
    }

    private var costTracked: Binding<Bool> {
        Binding(
            get: { model.settings.costPerDrink != nil },
            set: { on in model.updateSettings { $0.costPerDrink = on ? 8 : nil } }
        )
    }

    private var costBinding: Binding<Double> {
        Binding(
            get: { model.settings.costPerDrink ?? 8 },
            set: { value in model.updateSettings { $0.costPerDrink = value } }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { model.settings.reminderEnabled },
            set: { enabled in Task { await model.setRemindersEnabled(enabled) } }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { model.reminderTimeToday },
            set: { date in
                let parts = model.calendar.dateComponents([.hour, .minute], from: date)
                model.updateSettings {
                    $0.reminderHour = parts.hour ?? 20
                    $0.reminderMinute = parts.minute ?? 0
                }
            }
        )
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "?"
    }
}
