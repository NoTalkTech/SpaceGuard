import SwiftUI

struct CleanupResultView: View {
    let record: CleanupHistoryRecord
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: record.reachedGoalAfterExecution == true ? "checkmark.seal.fill" : "internaldrive.fill")
                    .font(.title2)
                    .foregroundColor(record.reachedGoalAfterExecution == true ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup Result")
                        .font(.headline)

                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.secondary.opacity(0.08))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        metricCard(title: "Freed", value: record.formattedSpaceFreed, color: .green, icon: "internaldrive.fill")
                        metricCard(title: "Deleted", value: "\(record.filesDeleted) files", color: .blue, icon: "trash.fill")
                        metricCard(title: "Duration", value: record.formattedDuration, color: .orange, icon: "clock.fill")
                        metricCard(
                            title: "Goal",
                            value: record.reachedGoalAfterExecution == true ? "Reached" : "Below target",
                            color: record.reachedGoalAfterExecution == true ? .green : .orange,
                            icon: record.reachedGoalAfterExecution == true ? "target" : "scope"
                        )
                    }

                    if let items = record.planItemsExecuted, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Executed Items")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(items, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.subheadline)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.05))
                            )
                        }
                    }

                    if let before = record.freeSpaceBefore, let after = record.freeSpaceAfter {
                        HStack(spacing: 12) {
                            metricCard(title: "Before", value: formatBytes(before), color: .orange, icon: "arrow.down.circle.fill")
                            metricCard(title: "After", value: formatBytes(after), color: .blue, icon: "arrow.up.circle.fill")
                        }
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 540, minHeight: 480)
    }

    private var headerSubtitle: String {
        if record.reachedGoalAfterExecution == true {
            return "Cleanup completed and disk space is back within the configured target."
        }
        return "Cleanup completed, but disk space is still below the configured target."
    }

    private func metricCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
