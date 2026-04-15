import SwiftUI

/// 批量清理确认视图
struct CleanupConfirmationView: View {
    let files: [FileItem]
    let rules: CleanupRules
    let onConfirm: ([FileSelection]) -> Void
    let onCancel: () -> Void

    @State private var lowRiskSelected = true
    @State private var mediumRiskSelected = false
    @State private var highRiskSelected = false
    @State private var expandedRiskLevel: RiskLevel?

    private var riskGroups: [RiskLevel: [FileItem]] {
        Dictionary(grouping: files) { $0.riskLevel }
    }

    private var lowRiskFiles: [FileItem] {
        riskGroups[.low] ?? []
    }

    private var mediumRiskFiles: [FileItem] {
        riskGroups[.medium] ?? []
    }

    private var highRiskFiles: [FileItem] {
        riskGroups[.high] ?? []
    }

    private var totalSpace: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    private var selectedFiles: [FileSelection] {
        var selections: [FileSelection] = []

        if lowRiskSelected {
            selections.append(contentsOf: lowRiskFiles.map { FileSelection(file: $0, shouldDelete: true) })
        }

        if mediumRiskSelected {
            selections.append(contentsOf: mediumRiskFiles.map { FileSelection(file: $0, shouldDelete: true) })
        }

        if highRiskSelected {
            selections.append(contentsOf: highRiskFiles.map { FileSelection(file: $0, shouldDelete: true) })
        }

        return selections
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Main content
            ScrollView {
                VStack(spacing: 16) {
                    // Summary section
                    summarySection

                    // Risk level sections
                    if !lowRiskFiles.isEmpty {
                        RiskLevelSection(
                            level: .low,
                            files: lowRiskFiles,
                            isSelected: lowRiskSelected,
                            isExpanded: expandedRiskLevel == .low,
                            onToggle: {
                                lowRiskSelected.toggle()
                            },
                            onExpand: {
                                expandedRiskLevel = expandedRiskLevel == .low ? nil : .low
                            }
                        )
                    }

                    if !mediumRiskFiles.isEmpty {
                        RiskLevelSection(
                            level: .medium,
                            files: mediumRiskFiles,
                            isSelected: mediumRiskSelected,
                            isExpanded: expandedRiskLevel == .medium,
                            onToggle: {
                                mediumRiskSelected.toggle()
                            },
                            onExpand: {
                                expandedRiskLevel = expandedRiskLevel == .medium ? nil : .medium
                            }
                        )
                    }

                    if !highRiskFiles.isEmpty {
                        RiskLevelSection(
                            level: .high,
                            files: highRiskFiles,
                            isSelected: highRiskSelected,
                            isExpanded: expandedRiskLevel == .high,
                            onToggle: {
                                highRiskSelected.toggle()
                            },
                            onExpand: {
                                expandedRiskLevel = expandedRiskLevel == .high ? nil : .high
                            }
                        )
                    }

                    // Warning section
                    warningSection
                }
                .padding()
            }

            Divider()

            // Footer actions
            footerSection
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "trash.circle.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Confirm Cleanup")
                    .font(.headline)

                Text("Review files before deletion")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Cleanup Summary")
                    .font(.headline)

                Spacer()

                Text("\(files.count) files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Review the risk groups below. SpaceGuard shows representative directories and the largest files instead of the full file tree.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    count: lowRiskFiles.count,
                    size: lowRiskFiles.reduce(0) { $0 + $1.size },
                    label: "Low Risk"
                )

                SummaryCard(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    count: mediumRiskFiles.count,
                    size: mediumRiskFiles.reduce(0) { $0 + $1.size },
                    label: "Medium Risk"
                )

                SummaryCard(
                    icon: "xmark.circle.fill",
                    color: .red,
                    count: highRiskFiles.count,
                    size: highRiskFiles.reduce(0) { $0 + $1.size },
                    label: "High Risk"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Important Notice")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()
            }

            Text("Files will be moved to Trash. You can restore them if needed. High-risk files are excluded by default.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )
    }

    private var footerSection: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape)
                .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                Text("Selected: \(selectedFiles.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Clean Up") {
                    onConfirm(selectedFiles)
                }
                .disabled(selectedFiles.isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    CleanupConfirmationView(
        files: FileItem.sample(),
        rules: CleanupRules(),
        onConfirm: { selections in
            print("Confirmed \(selections.count) files")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
