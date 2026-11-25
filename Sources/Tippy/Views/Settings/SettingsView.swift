import SwiftUI
import UniformTypeIdentifiers
import TippyModeration

struct SettingsView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pendingImport: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your pet") {
                    TextField("Name", text: setting(\.petName))
                        .accessibilityIdentifier("pet-name-field")
                }
                Section {
                    Stepper(value: setting(\.weeklyGoal), in: 0...70, step: 1) {
                        Text("Weekly goal: \(Int(model.settings.weeklyGoal)) drinks")
                    }
                    .accessibilityIdentifier("weekly-goal-stepper")
                    Stepper(value: setting(\.baselinePerWeek), in: 0...150, step: 1) {
                        Text("Before Tippy: \(Int(model.settings.baselinePerWeek)) a week")
                    }
                    .accessibilityIdentifier("baseline-stepper")
                    Stepper(value: setting(\.costPerDrink), in: 0...100, step: 0.5) {
                        Text("Cost per drink: \(model.settings.costPerDrink.formatted(.currency(code: currencyCode)))")
                    }
                    .accessibilityIdentifier("cost-stepper")
                    Picker("Weeks start on", selection: setting(\.firstWeekday)) {
                        Text("Monday").tag(2)
                        Text("Sunday").tag(1)
                    }
                    .accessibilityIdentifier("week-start-picker")
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Counted in US standard drinks (14 g of alcohol).")
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
                    Button {
                        importing = true
                    } label: {
                        Label("Restore from a backup", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("import-backup-button")
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Everything stays on this phone. Export a backup now and then (to Files or iCloud Drive) so a lost phone doesn't lose your history.")
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
                exportURL = try? model.exportBackup()
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pendingImport = try? Data(contentsOf: url)
            }
            .alert("Replace everything with this backup?", isPresented: importConfirmation) {
                Button("Replace", role: .destructive) {
                    if let data = pendingImport { model.importBackup(data) }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: {
                Text("Everything logged on this phone is replaced by what's in the backup.")
            }
        }
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<ModerationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
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

    private var importConfirmation: Binding<Bool> {
        Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })
    }

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    private var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "?"
    }
}
