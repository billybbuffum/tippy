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
        NavigationStack {
            Form {
                Section("Your pet") {
                    TextField("Name", text: $petName)
                        .accessibilityIdentifier("pet-name-field")
                        .onAppear { petName = wander.shownPet?.name ?? model.settings.petName }
                        .onChange(of: petName) { rename(to: petName) }
                }
                Section {
                    Stepper(value: goalBinding, in: 0...70, step: 1) {
                        Text("Weekly goal: \(Int(model.currentGoal)) drinks")
                    }
                    .accessibilityIdentifier("weekly-goal-stepper")
                    Stepper(value: setting(\.baselinePerWeek), in: 0...150, step: 1) {
                        Text("Before Tippy: \(Int(model.settings.baselinePerWeek)) a week")
                    }
                    .accessibilityIdentifier("baseline-stepper")
                    Toggle("Track what drinks cost", isOn: costTracked)
                        .accessibilityIdentifier("cost-toggle")
                    if let cost = model.settings.costPerDrink {
                        Stepper(value: costBinding, in: 0...100, step: 0.5) {
                            Text("Cost per drink: \(cost.formatted(.currency(code: currencyCode)))")
                        }
                        .accessibilityIdentifier("cost-stepper")
                    }
                    Picker("Weeks start on", selection: setting(\.firstWeekday)) {
                        Text("Monday").tag(2)
                        Text("Sunday").tag(1)
                    }
                    .accessibilityIdentifier("week-start-picker")
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Counted in US standard drinks (14 g of alcohol). A new goal applies from this week on; past weeks keep theirs.")
                }
                Section("Reminder") {
                    Toggle("Daily reminder", isOn: remindersBinding)
                        .accessibilityIdentifier("reminder-toggle")
                    if model.settings.reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .accessibilityIdentifier("reminder-time-picker")
                    }
                }
                Section {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Export a backup", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("export-backup-button")
                    }
                    Text("Backups include your notes and reflections. Keep them somewhere private.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("export-privacy-note")
                    Button {
                        importing = true
                    } label: {
                        Label("Restore from a backup", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("import-backup-button")
                    if UISmokeMode.isActive {
                        // XCUITest can't drive the system file picker reliably.
                        Button("Use demo backup") {
                            if let data = UISmokeMode.demoBackup() { pendingRestore = backup.prepareRestore(from: data) }
                        }
                        .accessibilityIdentifier("restore-demo-button")
                    }
                    if let restoredAt = backup.restoredAt {
                        Label("Backup restored at \(restoredAt.formatted(date: .omitted, time: .shortened))", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("restore-done-label")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Everything stays on this phone. Export a backup now and then (to Files or iCloud Drive) so a lost phone doesn't lose your history. A backup holds your log, coins, decorations and pets.")
                }
                Section("About") {
                    Text("Tippy is not medical advice. If you drink heavily every day, talk to a doctor before cutting back: stopping suddenly can be dangerous.")
                        .font(.footnote)
                    Link(destination: URL(string: "tel:18006624357")!) {
                        Label("SAMHSA helpline: 1-800-662-4357", systemImage: "phone")
                    }
                    LabeledContent("Build", value: buildNumber)
                        .accessibilityIdentifier("build-number-label")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings-done-button")
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
