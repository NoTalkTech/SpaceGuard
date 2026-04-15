import AppKit
import SwiftUI

struct RiskLevelSection: View {
    private static let previewDirectoryLimit = 5
    private static let previewFileLimit = 6

    fileprivate struct DirectorySummary: Identifiable {
        let path: String
        let fileCount: Int
        let totalSize: Int64

        var id: String { path }

        var name: String {
            let normalized = path.hasSuffix("/") ? String(path.dropLast()) : path
            let lastPathComponent = URL(fileURLWithPath: normalized).lastPathComponent
            return lastPathComponent.isEmpty ? normalized : lastPathComponent
        }
    }

    let level: RiskLevel
    let files: [FileItem]
    let isSelected: Bool
    let isExpanded: Bool
    let onToggle: () -> Void
    let onExpand: () -> Void

    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    private var previewDirectories: [DirectorySummary] {
        Dictionary(grouping: files) { parentDirectory(for: $0.path) }
            .map { path, groupedFiles in
                DirectorySummary(
                    path: path,
                    fileCount: groupedFiles.count,
                    totalSize: groupedFiles.reduce(0) { $0 + $1.size }
                )
            }
            .sorted { lhs, rhs in
                if lhs.totalSize == rhs.totalSize {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.totalSize > rhs.totalSize
            }
            .prefix(Self.previewDirectoryLimit)
            .map { $0 }
    }

    private var previewFiles: [FileItem] {
        files
            .sorted { lhs, rhs in
                if lhs.size == rhs.size {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.size > rhs.size
            }
            .prefix(Self.previewFileLimit)
            .map { $0 }
    }

    private var hiddenDirectoryCount: Int {
        max(0, directoryCount - previewDirectories.count)
    }

    private var hiddenFileCount: Int {
        max(0, files.count - previewFiles.count)
    }

    private var directoryCount: Int {
        Set(files.map { parentDirectory(for: $0.path) }).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? riskColor : .secondary)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(riskColor)

                            Spacer()

                            Text("\(files.count) files · \(formatBytes(totalSize))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onExpand)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if !previewDirectories.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Top directories")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(previewDirectories) { directory in
                                DirectorySummaryRow(directory: directory, riskColor: riskColor)
                            }

                            if hiddenDirectoryCount > 0 {
                                Text("\(hiddenDirectoryCount) more directories are hidden to keep review fast.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if !previewFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Largest files")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(previewFiles) { file in
                                FileRowView(file: file)
                            }

                            if hiddenFileCount > 0 {
                                Text("\(hiddenFileCount) more files are hidden. Use Finder to inspect directories before cleanup if needed.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(isSelected ? 0.12 : 0.05))
        )
    }

    private var title: String {
        switch level {
        case .low:
            return "Safe to clean now"
        case .medium:
            return "Needs review"
        case .high:
            return "High risk"
        }
    }

    private var summary: String {
        switch level {
        case .low:
            return "Disposable files that SpaceGuard considers safe to remove."
        case .medium:
            return "Potentially removable files that should be reviewed before cleanup."
        case .high:
            return "Files that are more likely to affect apps or user data. These stay off by default."
        }
    }

    private var riskColor: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func parentDirectory(for path: String) -> String {
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return directory.isEmpty ? "/" : directory
    }
}

private struct DirectorySummaryRow: View {
    let directory: RiskLevelSection.DirectorySummary
    let riskColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "folder")
                .font(.caption)
                .foregroundColor(riskColor)
                .frame(width: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(directory.name)
                    .font(.caption)
                    .lineLimit(1)

                Text(directory.path)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text("\(directory.fileCount) files")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Open") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: directory.path))
                }
                .buttonStyle(.plain)
                .font(.caption2)

                Text(formatBytes(directory.totalSize))
                    .font(.caption)
                    .monospacedDigit()
            }
            .foregroundColor(.accentColor)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.03))
        )
    }
}
