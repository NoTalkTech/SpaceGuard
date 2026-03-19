import SwiftUI

struct SettingsView: View {
    @StateObject private var progressTracker = ProgressTracker()
    @State private var rules = CleanupRules.load()
    @State private var diskStats: DiskStats?

    // Dialog states
    @State private var showAddOverride = false
    @State private var showAddPattern = false
    @State private var showConfigureSchedule = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            cleanupSettings
                .tabItem {
                    Label("Cleanup", systemImage: "trash")
                }

            advancedSettings
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }

            diskInfoView
                .tabItem {
                    Label("Disk Info", systemImage: "internaldrive")
                }
        }
        .frame(width: 500, height: 400)
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
    }

    private var generalSettings: some View {
        Form {
            Section("Risk Management") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Auto-clean low risk files", isOn: $rules.autoCleanLowRisk)
                        .help("Automatically delete files classified as low risk")

                    Toggle("Confirm medium risk files", isOn: $rules.confirmMediumRisk)
                        .help("Ask for confirmation before deleting medium risk files")

                    Toggle("Never delete high risk files", isOn: $rules.neverDeleteHighRisk)
                        .help("Prevent deletion of high risk files")
                }
            }

            Section("Age Rules") {
                VStack(alignment: .leading, spacing: 12) {
                    Stepper("Delete downloads older than \(rules.deleteDownloadsOlderThanDays) days",
                           value: $rules.deleteDownloadsOlderThanDays,
                           in: 1...365)

                    Stepper("Delete logs older than \(rules.deleteLogsOlderThanDays) days",
                           value: $rules.deleteLogsOlderThanDays,
                           in: 1...90)

                    Stepper("Delete cache older than \(rules.deleteCacheOlderThanDays) days",
                           value: $rules.deleteCacheOlderThanDays,
                           in: 1...30)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Save Settings") {
                        rules.save()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Reset to Defaults") {
                        rules = CleanupRules()
                        rules.save()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    private var cleanupSettings: some View {
        Form {
            Section("Quick Actions") {
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
                    ProgressView(value: progressTracker.currentProgress) {
                        Text(progressTracker.currentStatus)
                    }

                    Button("Cancel") {
                        if progressTracker.isScanning {
                            progressTracker.cancelScan()
                        } else {
                            progressTracker.cancelCleanup()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Statistics") {
                if let stats = diskStats {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Disk Usage: \(stats.formattedUsed) of \(stats.formattedTotal)")
                            .font(.headline)

                        ProgressView(value: stats.usedPercentage / 100) {
                            Text("\(String(format: "%.1f", stats.usedPercentage))% used")
                        }

                        HStack {
                            Text("Free: \(stats.formattedFree)")
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
        .padding()
    }

    private var diskInfoView: some View {
        Form {
            Section("Included Locations") {
                List(rules.includeLocations, id: \.self) { location in
                    Text(location)
                }
                .listStyle(.bordered)
            }

            Section("Excluded Locations") {
                List(rules.excludeLocations, id: \.self) { location in
                    Text(location)
                }
                .listStyle(.bordered)
            }

            Section("App Caches to Clean") {
                List(rules.appCachesToClean, id: \.self) { app in
                    Text(app)
                }
                .listStyle(.bordered)
            }
        }
        .padding()
    }

    private var advancedSettings: some View {
        Form {
            Section("File Type Rules") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable file type filtering", isOn: .constant(!rules.fileTypeRules.whitelistedExtensions.isEmpty))
                        .help("Only allow specific file extensions to be cleaned")

                    TextField("Whitelisted extensions (comma-separated)", text: .constant(rules.fileTypeRules.whitelistedExtensions.joined(separator: ", ")))
                        .disabled(true)
                        .help("e.g., 'log,cache,tmp' - leave empty to allow all")

                    TextField("Blacklisted extensions (comma-separated)", text: .constant(rules.fileTypeRules.blacklistedExtensions.joined(separator: ", ")))
                        .disabled(true)
                        .help("e.g., 'app,dmg,pkg' - these will never be cleaned")
                }
            }

            Section("Custom Risk Overrides") {
                List(rules.customRiskOverrides) { override in
                    HStack {
                        Text(override.path)
                        Spacer()
                        Text(override.riskLevel.rawValue)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Add Custom Override") {
                    showAddOverride = true
                }
                .buttonStyle(.bordered)
            }

            Section("Exclusion Patterns") {
                List(rules.exclusionPatterns, id: \.self) { pattern in
                    Text(pattern)
                }

                Button("Add Exclusion Pattern") {
                    showAddPattern = true
                }
                .buttonStyle(.bordered)
            }

            Section("Scheduled Cleanup") {
                if let schedule = rules.scheduledCleanup {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Enable scheduled cleanup", isOn: .constant(schedule.enabled))

                        if schedule.enabled {
                            Text("Frequency: \(schedule.frequency.rawValue)")
                            Text("Time: \(schedule.timeOfDay, style: .time)")

                            if let lastRun = schedule.lastRun {
                                Text("Last run: \(lastRun, style: .date) \(lastRun, style: .time)")
                            } else {
                                Text("Never run")
                            }
                        }
                    }
                }

                Button("Configure Schedule") {
                    showConfigureSchedule = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private func loadDiskStats() {
        let scanner = DiskScanner()
        diskStats = scanner.getDiskUsage()
    }

    private func colorForHealth(_ health: DiskHealth) -> Color {
        switch health {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        case .full: return .purple
        }
    }

    private func saveRules() {
        rules.save()
    }
}
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}