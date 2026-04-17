import SwiftUI

struct UnifiedSettingsView: View {
    @Binding var rules: CleanupRules
    @Binding var storageGoal: StorageGoal
    @Binding var showResetConfirmation: Bool
    @Binding var showAddOverride: Bool
    @Binding var showAddPattern: Bool
    @Binding var showConfigureSchedule: Bool
    @Binding var showFileTypeRulesEditor: Bool
    @Binding var showSaveSuccess: Bool
    @Binding var saveMessage: String

    let saveSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                safetySection

                Divider()

                cleanupGoalSection

                Divider()

                scopeSection

                Divider()

                advancedSection

                Divider()

                actionSection
            }
            .padding()
        }
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("Auto-clean low risk files", isOn: $rules.autoCleanLowRisk)
                .help("Automatically delete files classified as low risk")

            Toggle("Confirm medium risk files", isOn: $rules.confirmMediumRisk)
                .help("Ask for confirmation before deleting medium risk files")

            Toggle("Never delete high risk files", isOn: $rules.neverDeleteHighRisk)
                .help("Prevent deletion of high risk files")

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

    private var scopeSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Scope")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

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

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("File Type Rules")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("Edit...") {
                        showFileTypeRulesEditor = true
                    }
                    .buttonStyle(.bordered)
                }

                Text(fileTypeSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var cleanupGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanup Goal")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Cleanup Plan uses these targets to decide whether disk space is healthy and how much space needs to be reclaimed.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Stepper(value: minimumFreeSpaceGBBinding, in: 20...500, step: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minimum free space")
                    Text("\(minimumFreeSpaceGBBinding.wrappedValue) GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Stepper(value: minimumFreePercentBinding, in: 10...50, step: 5) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Minimum free percent")
                    Text("\(minimumFreePercentBinding.wrappedValue)% of total disk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Advanced")
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Custom Risk Overrides")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("Add Override") {
                        showAddOverride = true
                    }
                    .buttonStyle(.bordered)
                }

                if rules.customRiskOverrides.isEmpty {
                    Text("No custom risk overrides")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rules.customRiskOverrides) { override in
                            HStack {
                                Text(override.path)
                                    .font(.system(size: 13, weight: .regular))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(override.riskLevel.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button {
                                    if let index = rules.customRiskOverrides.firstIndex(where: { $0.id == override.id }) {
                                        rules.customRiskOverrides.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Exclusion Patterns")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("Add Pattern") {
                        showAddPattern = true
                    }
                    .buttonStyle(.bordered)
                }

                if rules.exclusionPatterns.isEmpty {
                    Text("No exclusion patterns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(rules.exclusionPatterns, id: \.self) { pattern in
                            HStack {
                                Text(pattern)
                                    .font(.system(size: 13, weight: .regular))
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    if let index = rules.exclusionPatterns.firstIndex(of: pattern) {
                                        rules.exclusionPatterns.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Scheduled Cleanup")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("Configure...") {
                        showConfigureSchedule = true
                    }
                    .buttonStyle(.bordered)
                }

                if let schedule = rules.scheduledCleanup, schedule.enabled {
                    Text("Runs \(schedule.frequency.rawValue.lowercased()) at \(schedule.timeOfDay, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Scheduled cleanup is disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var actionSection: some View {
        HStack(spacing: 12) {
            Button("Save Settings") {
                saveSettings()
            }
            .buttonStyle(.borderedProminent)

            Button("Reset to Defaults") {
                showResetConfirmation = true
            }
            .buttonStyle(.bordered)

            Spacer()

            if showSaveSuccess {
                Text(saveMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fileTypeSummary: String {
        let whitelist = rules.fileTypeRules.whitelistedExtensions
        let blacklist = rules.fileTypeRules.blacklistedExtensions

        if whitelist.isEmpty && blacklist.isEmpty {
            return "All file types are allowed."
        }

        if whitelist.isEmpty {
            return "All file types are allowed except: \(blacklist.joined(separator: ", "))"
        }

        if blacklist.isEmpty {
            return "Only these file types are allowed: \(whitelist.joined(separator: ", "))"
        }

        return "Allowed: \(whitelist.joined(separator: ", ")) • Excluded: \(blacklist.joined(separator: ", "))"
    }

    private var minimumFreeSpaceGBBinding: Binding<Int> {
        Binding(
            get: {
                max(1, Int(storageGoal.minimumFreeBytes / (1024 * 1024 * 1024)))
            },
            set: { newValue in
                storageGoal.minimumFreeBytes = Int64(newValue) * 1024 * 1024 * 1024
            }
        )
    }

    private var minimumFreePercentBinding: Binding<Int> {
        Binding(
            get: {
                Int((storageGoal.minimumFreePercent * 100).rounded())
            },
            set: { newValue in
                storageGoal.minimumFreePercent = Double(newValue) / 100.0
            }
        )
    }
}
