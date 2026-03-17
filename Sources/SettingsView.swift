import SwiftUI

struct SettingsView: View {
    @StateObject private var progressTracker = ProgressTracker()
    @State private var rules = CleanupRules.load()
    @State private var diskStats: DiskStats?

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

            diskInfoView
                .tabItem {
                    Label("Disk Info", systemImage: "internaldrive")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadDiskStats()
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Risk Management") {
                Toggle("Auto-clean low risk files", isOn: $rules.autoCleanLowRisk)
                    .help("Automatically delete files classified as low risk")

                Toggle("Confirm medium risk files", isOn: $rules.confirmMediumRisk)
                    .help("Ask for confirmation before deleting medium risk files")

                Toggle("Never delete high risk files", isOn: $rules.neverDeleteHighRisk)
                    .help("Prevent deletion of high risk files")
            }

            Section("Age Rules") {
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

            Section {
                Button("Save Settings") {
                    rules.save()
                }
                .buttonStyle(.borderedProminent)

                Button("Reset to Defaults") {
                    rules = CleanupRules()
                    rules.save()
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

                Button("Quick Cleanup") {
                    Task {
                        await progressTracker.quickCleanup(rules: rules)
                    }
                }
                .disabled(progressTracker.isCleaning)

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
                }
            }

            Section("Statistics") {
                if let stats = diskStats {
                    VStack(alignment: .leading, spacing: 8) {
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
            }

            Section("Excluded Locations") {
                List(rules.excludeLocations, id: \.self) { location in
                    Text(location)
                }
            }

            Section("App Caches to Clean") {
                List(rules.appCachesToClean, id: \.self) { app in
                    Text(app)
                }
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}