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
    @State private var customFileSelections: [UUID: Bool] = [:]
    @State private var showingDetails = false
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    lowRiskSelected.toggle()
                                }
                            },
                            onExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    expandedRiskLevel = expandedRiskLevel == .low ? nil : .low
                                }
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    mediumRiskSelected.toggle()
                                }
                            },
                            onExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    expandedRiskLevel = expandedRiskLevel == .medium ? nil : .medium
                                }
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    highRiskSelected.toggle()
                                }
                            },
                            onExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    expandedRiskLevel = expandedRiskLevel == .high ? nil : .high
                                }
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

// MARK: - Supporting Views

struct RiskLevelSection: View {
    let level: RiskLevel
    let files: [FileItem]
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void

    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Button(action: onExpand) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? riskColor : .secondary)
                        .onTapGesture {
                            onToggle()
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("\(level.rawValue) Risk")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(riskColor)

                            Spacer()

                            Text("\(files.count) files · \(formatBytes(totalSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            // Expanded file list
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        FileRowView(file: file)
                    }
                }
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(isSelected ? 0.15 : 0.05))
        )
    }

    private var riskColor: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct FileRowView: View {
    let file: FileItem

    var body: some View {
        HStack {
            Image(systemName: fileIcon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.caption)
                    .lineLimit(1)

                Text(file.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Text(formatBytes(file.size))
                    .font(.caption)
                    .monospacedDigit()

                Text(riskBadge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(riskColor.opacity(0.2))
                    .cornerRadius(4)
                    .foregroundColor(riskColor)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.03))
        )
    }

    private var fileIcon: String {
        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "log": return "doc.text"
        case "cache", "tmp", "temp": return "archivebox"
        case "zip", "tar", "gz": return "archivebox.fill"
        case "jpg", "jpeg", "png", "gif": return "photo"
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi": return "film"
        default: return "doc.fill"
        }
    }

    private var riskColor: Color {
        switch file.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var riskBadge: String {
        switch file.riskLevel {
        case .low: return "Safe"
        case .medium: return "Confirm"
        case .high: return "High"
        }
    }
}

struct SummaryCard: View {
    let icon: String
    let color: Color
    let count: Int
    let size: Int64
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formatBytes(size))
                .font(.caption)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
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
