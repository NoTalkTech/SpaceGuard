import SwiftUI

// MARK: - General Settings View
struct GeneralSettingsView: View {
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
