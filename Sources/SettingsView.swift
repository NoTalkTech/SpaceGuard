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

    // Rule conflicts
    @State private var ruleConflicts: [RuleConflict] = []
    @State private var showRuleConflicts = false

    // Sidebar selection
    @State private var selectedTab: SidebarTab = .general

    enum SidebarTab: String, CaseIterable {
        case general = "General"
        case cleanup = "Cleanup"
        case fileTypes = "File Types"
        case riskManagement = "Risk Management"
        case diskInfo = "Disk Info"
        case advanced = "Advanced"
        case presetCleanup = "Preset Cleanup"
        case history = "History"
        case statistics = "Statistics"

        var icon: String {
            switch self {
            case .general: return "gear"
            case .cleanup: return "trash"
            case .fileTypes: return "doc.text"
            case .riskManagement: return "exclamationmark.triangle"
            case .diskInfo: return "internaldrive"
            case .advanced: return "slider.horizontal.3"
            case .presetCleanup: return "checklist"
            case .history: return "clock.arrow.circlepath"
            case .statistics: return "chart.bar.xaxis"
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
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                            )
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
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
                case .presetCleanup:
                    CleanupPresetsView()
                case .history:
                    CleanupHistoryView()
                case .statistics:
                    CleanupStatisticsView()
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
                            if ruleConflicts.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .onTapGesture {
                                        showRuleConflicts = true
                                    }
                            }
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
        .sheet(isPresented: $showRuleConflicts) {
            RuleConflictsView(isPresented: $showRuleConflicts, conflicts: ruleConflicts)
        }
    }

    private func loadDiskStats() {
        let scanner = DiskScanner()
        diskStats = scanner.getDiskUsage()
    }

    private func saveRules() {
        // Validate rules before saving
        let cleanupEngine = CleanupEngine()
        let (_, conflicts) = cleanupEngine.validateRules(rules)
        ruleConflicts = conflicts

        if !conflicts.isEmpty {
            showRuleConflicts = true
            saveMessage = "Settings saved with \(conflicts.count) rule conflict(s)"
        } else {
            saveMessage = "Settings saved successfully"
        }

        rules.save()
        showSaveSuccess = true

        // Auto-hide after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSaveSuccess = false
        }
    }

    private func validateRules() {
        let cleanupEngine = CleanupEngine()
        let (_, conflicts) = cleanupEngine.validateRules(rules)
        ruleConflicts = conflicts
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Risk Management Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Risk Management")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Auto-clean low risk files", isOn: $rules.autoCleanLowRisk)
                            .help("Automatically delete files classified as low risk")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .toggleStyle(.switch)
                            .animation(.easeInOut(duration: 0.2), value: rules.autoCleanLowRisk)

                        Toggle("Confirm medium risk files", isOn: $rules.confirmMediumRisk)
                            .help("Ask for confirmation before deleting medium risk files")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .toggleStyle(.switch)
                            .animation(.easeInOut(duration: 0.2), value: rules.confirmMediumRisk)

                        Toggle("Never delete high risk files", isOn: $rules.neverDeleteHighRisk)
                            .help("Prevent deletion of high risk files")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .toggleStyle(.switch)
                            .animation(.easeInOut(duration: 0.2), value: rules.neverDeleteHighRisk)
                    }
                }

                Divider()

                // Age Rules Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Age Rules")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

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

                Divider()

                // Action Buttons
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Save Settings") {
                            rules.save()
                            saveMessage = "Settings saved successfully"
                            showSaveSuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showSaveSuccess = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .transition(.scale.combined(with: .opacity))

                        Button("Reset to Defaults") {
                            showResetConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Quick Actions Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Button("Scan Disk Now") {
                            Task {
                                await progressTracker.startScan()
                            }
                        }
                        .disabled(progressTracker.isScanning)
                        .buttonStyle(.borderedProminent)

                        Button("Quick Cleanup") {
                            Task {
                                await progressTracker.quickCleanup(rules: rules)
                            }
                        }
                        .disabled(progressTracker.isCleaning)
                        .buttonStyle(.borderedProminent)

                        if progressTracker.isScanning || progressTracker.isCleaning {
                            CleanupProgressView(
                                progressTracker: progressTracker,
                                onCancel: {
                                    if progressTracker.isScanning {
                                        progressTracker.cancelScan()
                                    } else {
                                        progressTracker.cancelCleanup()
                                    }
                                }
                            )
                        }
                    }
                }

                Divider()

                // Statistics Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                    }
                }
            }
            .padding()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // File Type Rules Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Type Rules")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("Whitelist: (all file types allowed)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Text("Blacklist: \(rules.fileTypeRules.blacklistedExtensions.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#86868b"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Risk Management Settings View
private struct RiskManagementSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showAddOverride: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Custom Risk Overrides Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Custom Risk Overrides")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        if rules.customRiskOverrides.isEmpty {
                            Text("No custom risk overrides")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(rules.customRiskOverrides) { override in
                                    HStack {
                                        Text(override.path)
                                            .font(.system(size: 13, weight: .regular))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Text(override.riskLevel.rawValue)
                                            .font(.system(size: 13, weight: .regular))
                                            .foregroundColor(Color(hex: "#86868b"))
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                                .onDelete { indices in
                                    rules.customRiskOverrides.remove(atOffsets: indices)
                                }
                            }
                            .frame(maxHeight: 120)
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
            .padding()
        }
    }
}

// MARK: - Disk Info Settings View
private struct DiskInfoSettingsView: View {
    @Binding var rules: CleanupRules

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                EditableListSection(
                    title: "Included Locations",
                    items: $rules.includeLocations,
                    placeholder: "Add location path..."
                )

                Divider()

                EditableListSection(
                    title: "Excluded Locations",
                    items: $rules.excludeLocations,
                    placeholder: "Add excluded path..."
                )

                Divider()

                EditableListSection(
                    title: "App Caches to Clean",
                    items: $rules.appCachesToClean,
                    placeholder: "Add app bundle ID..."
                )
            }
            .padding()
        }
    }
}

// MARK: - Advanced Settings View
private struct AdvancedSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var showAddPattern: Bool
    @Binding var showConfigureSchedule: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Exclusion Patterns Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exclusion Patterns")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        if rules.exclusionPatterns.isEmpty {
                            Text("No exclusion patterns")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#86868b"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(rules.exclusionPatterns, id: \.self) { pattern in
                                    HStack {
                                        Text(pattern)
                                            .font(.system(size: 13, weight: .regular))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Button(action: {
                                            if let index = rules.exclusionPatterns.firstIndex(of: pattern) {
                                                rules.exclusionPatterns.remove(at: index)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red)
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(4)
                                }
                            }
                            .frame(maxHeight: 120)
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

                Divider()

                // Scheduled Cleanup Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scheduled Cleanup")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        if let schedule = rules.scheduledCleanup {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Enable scheduled cleanup", isOn: .constant(schedule.enabled))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .toggleStyle(.switch)

                                if schedule.enabled {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Frequency: \(schedule.frequency.rawValue)")
                                            .font(.system(size: 13, weight: .regular))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Time: \(schedule.timeOfDay, style: .time)")
                                            .font(.system(size: 13, weight: .regular))
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if let lastRun = schedule.lastRun {
                                            Text("Last run: \(lastRun, style: .date) \(lastRun, style: .time)")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color(hex: "#86868b"))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text("Never run")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(Color(hex: "#86868b"))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
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
            .padding()
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
        HStack(alignment: .center, spacing: 12) {
            Text("\(label)")
                .font(.system(size: 13, weight: .regular))
                .frame(width: 180, alignment: .leading)

            HStack(spacing: 8) {
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
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(hex: "#86868b"))

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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
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
                        .foregroundColor(Color(hex: "#86868b"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { item in
                            HStack {
                                Text(item)
                                    .font(.system(size: 13, weight: .regular))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer()
                                Button(action: {
                                    if let index = items.firstIndex(of: item) {
                                        items.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                    .frame(maxHeight: 120)
                }

                // Info text
                Text("Click trash icon to delete items")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#86868b"))
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