import SwiftUI

struct SettingsView: View {
    @StateObject private var progressTracker = ProgressTracker()
    @State private var rules = CleanupRules.load()
    @State private var diskStats: DiskStats?

    // Dialog states
    @State private var showAddOverride = false
    @State private var showAddPattern = false
    @State private var showConfigureSchedule = false
    @State private var showFileTypeRulesEditor = false

    // Save feedback
    @State private var showSaveSuccess = false
    @State private var saveMessage = ""

    // Reset confirmation
    @State private var showResetConfirmation = false

    // Sidebar selection
    @State private var selectedTab: SidebarTab = .general

    enum SidebarTab: String, CaseIterable {
        case general = "General"
        case cleanup = "Cleanup"
        case fileTypes = "File Types"
        case riskManagement = "Risk Management"
        case diskInfo = "Disk Info"
        case advanced = "Advanced"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .cleanup: return "trash"
            case .fileTypes: return "doc.text"
            case .riskManagement: return "exclamationmark.triangle"
            case .diskInfo: return "internaldrive"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(SidebarTab.allCases, id: \.self) { tab in
                            HStack {
                                Image(systemName: tab.icon)
                                    .frame(width: 20, height: 20)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .regular))
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTab = tab
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(width: 200)
                .background(Color(hex: "#b3b3b3").opacity(0.1))
            }
            .frame(width: 200)
            .background(Color(hex: "#b3b3b3").opacity(0.1))

            Divider()

            // Content area
            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView(
                        rules: $rules,
                        showResetConfirmation: $showResetConfirmation,
                        showSaveSuccess: $showSaveSuccess,
                        saveMessage: $saveMessage,
                        saveRules: saveRules
                    )
                case .cleanup:
                    CleanupSettingsView(
                        progressTracker: progressTracker,
                        rules: rules,
                        diskStats: diskStats,
                        loadDiskStats: loadDiskStats
                    )
                case .fileTypes:
                    FileTypesSettingsView(
                        rules: $rules,
                        showFileTypeRulesEditor: $showFileTypeRulesEditor
                    )
                case .riskManagement:
                    RiskManagementSettingsView(
                        rules: $rules,
                        showAddOverride: $showAddOverride
                    )
                case .diskInfo:
                    DiskInfoSettingsView(rules: $rules)
                case .advanced:
                    AdvancedSettingsView(
                        rules: $rules,
                        showAddPattern: $showAddPattern,
                        showConfigureSchedule: $showConfigureSchedule
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 700, height: 500)
        .onAppear {
            loadDiskStats()
        }
        .sheet(isPresented: $showAddOverride) {
            AddCustomRiskOverrideView(
                isPresented: $showAddOverride,
                customRiskOverrides: $rules.customRiskOverrides
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showAddPattern) {
            AddExclusionPatternView(
                isPresented: $showAddPattern,
                exclusionPatterns: $rules.exclusionPatterns
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showConfigureSchedule) {
            ConfigureScheduleView(
                isPresented: $showConfigureSchedule,
                scheduledCleanup: $rules.scheduledCleanup
            )
            .onDisappear {
                saveRules()
            }
        }
        .sheet(isPresented: $showFileTypeRulesEditor) {
            FileTypeRulesEditorView(
                isPresented: $showFileTypeRulesEditor,
                fileTypeRules: $rules.fileTypeRules
            )
            .onDisappear {
                saveRules()
            }
        }
        .overlay(
            Group {
                if showSaveSuccess {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(saveMessage)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: showSaveSuccess)
                }
            }
        )
    }

    private func loadDiskStats() {
        let scanner = DiskScanner()
        diskStats = scanner.getDiskUsage()
    }

    private func saveRules() {
        rules.save()
        saveMessage = "Settings saved successfully"
        showSaveSuccess = true

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveSuccess = false
        }
    }
}

// MARK: - General Settings View
private struct GeneralSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showResetConfirmation: Bool
    @Binding var showSaveSuccess: Bool
    @Binding var saveMessage: String
    let saveRules: () -> Void

    var body: some View {
        Form {
            Section("Risk Management") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-clean low risk files", isOn: $rules.autoCleanLowRisk)
                        .help("Automatically delete files classified as low risk")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Confirm medium risk files", isOn: $rules.confirmMediumRisk)
                        .help("Ask for confirmation before deleting medium risk files")
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Never delete high risk files", isOn: $rules.neverDeleteHighRisk)
                        .help("Prevent deletion of high risk files")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Age Rules") {
                VStack(alignment: .leading, spacing: 12) {
                    AgeRuleInput(
                        label: "Delete downloads older than",
                        value: $rules.deleteDownloadsOlderThanDays,
                        range: 1...365,
                        unit: "days"
                    )

                    AgeRuleInput(
                        label: "Delete logs older than",
                        value: $rules.deleteLogsOlderThanDays,
                        range: 1...90,
                        unit: "days"
                    )

                    AgeRuleInput(
                        label: "Delete cache older than",
                        value: $rules.deleteCacheOlderThanDays,
                        range: 1...30,
                        unit: "days"
                    )
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Save Settings") {
                        rules.save()
                        saveMessage = "Settings saved successfully"
                        showSaveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSaveSuccess = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                rules = CleanupRules()
                rules.save()
                saveMessage = "Settings reset to defaults"
                showSaveSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showSaveSuccess = false
                }
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This action cannot be undone.")
        }
    }
}

// MARK: - Cleanup Settings View
private struct CleanupSettingsView: View {
    @ObservedObject var progressTracker: ProgressTracker
    let rules: CleanupRules
    let diskStats: DiskStats?
    let loadDiskStats: () -> Void

    var body: some View {
        Form {
            Section("Quick Actions") {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Scan Disk Now") {
                        Task {
                            await progressTracker.startScan()
                        }
                    }
                    .disabled(progressTracker.isScanning)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Quick Cleanup") {
                        Task {
                            await progressTracker.quickCleanup(rules: rules)
                        }
                    }
                    .disabled(progressTracker.isCleaning)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if progressTracker.isScanning || progressTracker.isCleaning {
                        ProgressView(value: progressTracker.currentProgress) {
                            Text(progressTracker.currentStatus)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Cancel") {
                            if progressTracker.isScanning {
                                progressTracker.cancelScan()
                            } else {
                                progressTracker.cancelCleanup()
                            }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Section("Statistics") {
                VStack(alignment: .leading, spacing: 12) {
                    if let stats = diskStats {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Disk Usage: \(stats.formattedUsed) of \(stats.formattedTotal)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ProgressView(value: stats.usedPercentage / 100) {
                                Text("\(String(format: "%.1f", stats.usedPercentage))% used")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                Text("Free: \(stats.formattedFree)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Text("Status: \(stats.healthStatus.rawValue)")
                                    .foregroundColor(colorForHealth(stats.healthStatus))
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }

                    Button("Refresh Disk Info") {
                        loadDiskStats()
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func colorForHealth(_ health: DiskHealth) -> Color {
        switch health {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        case .full: return .purple
        }
    }
}

// MARK: - File Types Settings View
private struct FileTypesSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showFileTypeRulesEditor: Bool

    var body: some View {
        Form {
            Section("File Type Rules") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Enable file type filtering", isOn: .constant(!rules.fileTypeRules.whitelistedExtensions.isEmpty))
                            .help("Only allow specific file extensions to be cleaned")
                            .disabled(true)

                        Spacer()

                        Button("Edit...") {
                            showFileTypeRulesEditor = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !rules.fileTypeRules.whitelistedExtensions.isEmpty {
                        Text("Whitelist: \(rules.fileTypeRules.whitelistedExtensions.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Whitelist: (all file types allowed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Blacklist: \(rules.fileTypeRules.blacklistedExtensions.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Risk Management Settings View
private struct RiskManagementSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showAddOverride: Bool

    var body: some View {
        Form {
            Section("Custom Risk Overrides") {
                VStack(alignment: .leading, spacing: 12) {
                    if rules.customRiskOverrides.isEmpty {
                        Text("No custom risk overrides")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(rules.customRiskOverrides) { override in
                                HStack {
                                    Text(override.path)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    Text(override.riskLevel.rawValue)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onDelete { indices in
                                rules.customRiskOverrides.remove(atOffsets: indices)
                            }
                        }
                        .frame(maxHeight: 120)
                        .listStyle(.bordered)
                    }

                    HStack {
                        Button("Add Custom Override") {
                            showAddOverride = true
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Disk Info Settings View
private struct DiskInfoSettingsView: View {
    @Binding var rules: CleanupRules

    var body: some View {
        Form {
            EditableListSection(
                title: "Included Locations",
                items: $rules.includeLocations,
                placeholder: "Add location path..."
            )

            EditableListSection(
                title: "Excluded Locations",
                items: $rules.excludeLocations,
                placeholder: "Add excluded path..."
            )

            EditableListSection(
                title: "App Caches to Clean",
                items: $rules.appCachesToClean,
                placeholder: "Add app bundle ID..."
            )
        }
    }
}

// MARK: - Advanced Settings View
private struct AdvancedSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showAddPattern: Bool
    @Binding var showConfigureSchedule: Bool

    var body: some View {
        Form {
            Section("Exclusion Patterns") {
                VStack(alignment: .leading, spacing: 12) {
                    if rules.exclusionPatterns.isEmpty {
                        Text("No exclusion patterns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(rules.exclusionPatterns, id: \.self) { pattern in
                                Text(pattern)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .onDelete { indices in
                                rules.exclusionPatterns.remove(atOffsets: indices)
                            }
                        }
                        .frame(maxHeight: 120)
                        .listStyle(.bordered)
                    }

                    HStack {
                        Button("Add Exclusion Pattern") {
                            showAddPattern = true
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Scheduled Cleanup") {
                VStack(alignment: .leading, spacing: 12) {
                    if let schedule = rules.scheduledCleanup {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable scheduled cleanup", isOn: .constant(schedule.enabled))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if schedule.enabled {
                                Text("Frequency: \(schedule.frequency.rawValue)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Time: \(schedule.timeOfDay, style: .time)")
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let lastRun = schedule.lastRun {
                                    Text("Last run: \(lastRun, style: .date) \(lastRun, style: .time)")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text("Never run")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    Button("Configure Schedule") {
                        showConfigureSchedule = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Supporting Views
private struct AgeRuleInput: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    @State private var textValue: String = ""
    @State private var showingError = false

    var body: some View {
        HStack {
            Text("\(label)")
                .frame(minWidth: 180, alignment: .leading)

            Spacer(minLength: 20)

            HStack {
                TextField("", text: $textValue)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: textValue) { newValue in
                        // Validate and update binding if valid
                        if let intValue = Int(newValue), range.contains(intValue) {
                            value = intValue
                            showingError = false
                        } else if newValue.isEmpty {
                            // Allow empty during editing
                            showingError = false
                        } else {
                            showingError = true
                        }
                    }
                    .onSubmit {
                        // On submit, reset to current value if invalid
                        if let intValue = Int(textValue), range.contains(intValue) {
                            value = intValue
                            showingError = false
                        } else {
                            textValue = String(value)
                            showingError = false
                        }
                    }

                Text(unit)
                    .foregroundColor(.secondary)

                Stepper("", value: $value, in: range)
                    .labelsHidden()
                    .onChange(of: value) { _ in
                        // Update text when stepper changes
                        textValue = String(value)
                        showingError = false
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            textValue = String(value)
        }
        .onChange(of: value) { newValue in
            // Sync text when binding changes externally
            if textValue != String(newValue) {
                textValue = String(newValue)
            }
        }
        .alert("Invalid Value", isPresented: $showingError) {
            Button("OK") {
                textValue = String(value)
                showingError = false
            }
        } message: {
            Text("Please enter a value between \(range.lowerBound) and \(range.upperBound)")
        }
    }
}

private struct EditableListSection: View {
    let title: String
    @Binding var items: [String]
    let placeholder: String

    @State private var newItem = ""

    var body: some View {
        Section(title) {
            VStack(alignment: .leading, spacing: 8) {
                // Add new item
                HStack {
                    TextField(placeholder, text: $newItem)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addItem()
                        }

                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Add item")
                }

                // List of items
                if items.isEmpty {
                    Text("No items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    List {
                        ForEach(items, id: \.self) { item in
                            Text(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onDelete { indices in
                            items.remove(atOffsets: indices)
                        }
                    }
                    .frame(maxHeight: 120)
                    .listStyle(.bordered)
                }

                // Info text
                Text("Swipe left to delete items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func addItem() {
        let trimmed = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !items.contains(trimmed) {
            items.append(trimmed)
        }
        newItem = ""
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}