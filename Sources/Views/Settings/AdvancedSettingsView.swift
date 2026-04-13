import SwiftUI

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
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
