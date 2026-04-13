import SwiftUI

// MARK: - Cleanup Settings View
struct CleanupSettingsView: View {
    @ObservedObject var progressTracker: ProgressTracker
    let rules: CleanupRules
    let diskStats: DiskStats?
    let loadDiskStats: () -> Void

    // Batch cleanup confirmation
    @State private var showQuickCleanupConfirmation = false
    @State private var quickCleanupFiles: [FileItem] = []
    @State private var isScanningForCleanup = false
    @State private var scanError: String? = nil
    private let cleanupEngine = CleanupEngine()

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
                        .disabled(progressTracker.isScanning || isScanningForCleanup)
                        .buttonStyle(.borderedProminent)

                        Button("Quick Cleanup") {
                            startQuickCleanupScan()
                        }
                        .disabled(progressTracker.isCleaning || isScanningForCleanup)
                        .buttonStyle(.borderedProminent)

                        if progressTracker.isScanning || progressTracker.isCleaning || isScanningForCleanup {
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
        .sheet(isPresented: $showQuickCleanupConfirmation) {
            CleanupConfirmationView(
                files: quickCleanupFiles,
                rules: rules,
                onConfirm: { selections in
                    performQuickBatchCleanup(selections)
                    showQuickCleanupConfirmation = false
                },
                onCancel: {
                    showQuickCleanupConfirmation = false
                }
            )
        }
        .alert("Quick Cleanup Error", isPresented: Binding(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button("OK") {
                scanError = nil
            }
        } message: {
            Text(scanError ?? "")
        }
    }

    private func startQuickCleanupScan() {
        isScanningForCleanup = true

        Task {
            let scanner = DiskScanner()
            var allFiles: [FileItem] = []
            var scanErrors: [Error] = []

            // Scan common cache locations from CleanupEngine
            let cleanupEngine = CleanupEngine()
            let cachePaths = cleanupEngine.getQuickCleanupPaths()

            for path in cachePaths {
                guard FileManager.default.fileExists(atPath: path) else { continue }

                do {
                    let scanResult = try await scanner.scanDirectory(at: path) { _, _ in }
                    let analyzer = RiskAnalyzer()
                    let analyzedFiles = analyzer.analyzeFiles(scanResult.files, rules: rules)
                    allFiles.append(contentsOf: analyzedFiles)
                } catch {
                    print("Scan error: \(error)")
                    scanErrors.append(error)
                    // Continue scanning other paths instead of returning
                }
            }

            DispatchQueue.main.async {
                isScanningForCleanup = false

                // If there were scan errors, show them to the user
                if !scanErrors.isEmpty {
                    let errorCount = scanErrors.count
                    scanError = "Encountered \(errorCount) error(s) while scanning, some files may not be included"
                }

                // Filter for low-risk files (only if no scan errors)
                let lowRiskFiles = allFiles.filter { $0.riskLevel == .low }

                if lowRiskFiles.isEmpty {
                    scanError = "No low-risk files found to clean"
                } else {
                    quickCleanupFiles = lowRiskFiles
                    showQuickCleanupConfirmation = true
                    scanError = nil
                }
            }
        }
    }

    private func performQuickBatchCleanup(_ selections: [FileSelection]) {
        Task {
            let result = await cleanupEngine.performBatchCleanup(selections: selections) { current, total, freed in
                DispatchQueue.main.async {
                    // Update progress tracker for UI display
                    progressTracker.filesProcessed = current
                    progressTracker.totalFiles = total
                    progressTracker.spaceFreed = freed
                    progressTracker.currentProgress = Double(current) / Double(max(total, 1))
                    progressTracker.currentStatus = "Cleaned \(current)/\(total) files, freed \(ByteCountFormatter.string(fromByteCount: freed, countStyle: .file))"
                }
            }

            DispatchQueue.main.async {
                progressTracker.currentStatus = "Quick cleanup complete: \(result.filesDeleted) files deleted, freed \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file))"
                progressTracker.currentProgress = 1.0

                // Record cleanup history
                let record = CleanupHistoryRecord(
                    id: UUID(),
                    timestamp: Date(),
                    cleanupType: .quick,
                    filesDeleted: result.filesDeleted,
                    spaceFreed: result.spaceFreed,
                    duration: result.duration,
                    errors: result.errors.count,
                    wasCancelled: false
                )
                CleanupHistoryManager.shared.addRecord(record)
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
