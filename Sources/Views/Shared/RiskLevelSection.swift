import AppKit
import SwiftUI

struct RiskLevelSection: View {
    private static let pageSize = 200

    enum DisplayMode: String, CaseIterable, Identifiable {
        case directories = "Directories"
        case files = "Files"

        var id: String { rawValue }
    }

    private enum SortOption: String, CaseIterable, Identifiable {
        case sizeDescending = "Largest First"
        case nameAscending = "Name"
        case pathAscending = "Path"
        case countDescending = "Most Files"
        case modifiedDescending = "Recently Modified"

        var id: String { rawValue }
    }

    fileprivate struct DirectoryGroup: Identifiable {
        let path: String
        let fileCount: Int
        let totalSize: Int64
        let mostRecentModified: Date
        let sampleReasons: String

        var id: String { path }

        var name: String {
            let normalized = path.hasSuffix("/") ? String(path.dropLast()) : path
            let lastPathComponent = URL(fileURLWithPath: normalized).lastPathComponent
            return lastPathComponent.isEmpty ? normalized : lastPathComponent
        }

        var formattedSize: String {
            formatBytes(totalSize)
        }

        var formattedModified: String {
            DateFormatter.localizedString(from: mostRecentModified, dateStyle: .short, timeStyle: .short)
        }
    }

    let level: RiskLevel
    let files: [FileItem]
    let isSelected: Bool
    let isExpanded: Bool
    let displayMode: DisplayMode
    let onToggle: () -> Void
    let onExpand: () -> Void

    @State private var searchText = ""
    @State private var visibleCount = pageSize
    @State private var sortOption: SortOption = .sizeDescending
    @State private var expandedDirectoryPath: String?
    @State private var expandedDirectoryVisibleCount = pageSize

    private var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    private var filteredFiles: [FileItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingFiles: [FileItem]

        if query.isEmpty {
            matchingFiles = files
        } else {
            matchingFiles = files.filter { file in
                file.name.localizedCaseInsensitiveContains(query) ||
                file.path.localizedCaseInsensitiveContains(query) ||
                file.reason.localizedCaseInsensitiveContains(query)
            }
        }

        return matchingFiles.sorted { lhs, rhs in
            switch sortOption {
            case .sizeDescending:
                if lhs.size == rhs.size {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.size > rhs.size
            case .nameAscending:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .pathAscending, .countDescending:
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            case .modifiedDescending:
                if lhs.modified == rhs.modified {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.modified > rhs.modified
            }
        }
    }

    private var filteredDirectoryGroups: [DirectoryGroup] {
        let groups = Dictionary(grouping: files) { parentDirectory(for: $0.path) }
            .map { path, groupedFiles in
                let reasons = groupedFiles
                    .map(\.reason)
                    .reduce(into: [String: Int]()) { counts, reason in
                        counts[reason, default: 0] += 1
                    }
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return lhs.key < rhs.key
                        }
                        return lhs.value > rhs.value
                    }
                    .prefix(2)
                    .map(\.key)
                    .joined(separator: ", ")

                return DirectoryGroup(
                    path: path,
                    fileCount: groupedFiles.count,
                    totalSize: groupedFiles.reduce(0) { $0 + $1.size },
                    mostRecentModified: groupedFiles.map(\.modified).max() ?? .distantPast,
                    sampleReasons: reasons
                )
            }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchingGroups: [DirectoryGroup]

        if query.isEmpty {
            matchingGroups = groups
        } else {
            matchingGroups = groups.filter { group in
                group.name.localizedCaseInsensitiveContains(query) ||
                group.path.localizedCaseInsensitiveContains(query) ||
                group.sampleReasons.localizedCaseInsensitiveContains(query)
            }
        }

        return matchingGroups.sorted { lhs, rhs in
            switch sortOption {
            case .sizeDescending:
                if lhs.totalSize == rhs.totalSize {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.totalSize > rhs.totalSize
            case .nameAscending:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .pathAscending:
                return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
            case .countDescending:
                if lhs.fileCount == rhs.fileCount {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.fileCount > rhs.fileCount
            case .modifiedDescending:
                if lhs.mostRecentModified == rhs.mostRecentModified {
                    return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
                }
                return lhs.mostRecentModified > rhs.mostRecentModified
            }
        }
    }

    private var visibleFiles: ArraySlice<FileItem> {
        filteredFiles.prefix(visibleCount)
    }

    private var visibleDirectoryGroups: ArraySlice<DirectoryGroup> {
        filteredDirectoryGroups.prefix(visibleCount)
    }

    private var remainingFileCount: Int {
        max(0, filteredFiles.count - visibleFiles.count)
    }

    private var remainingDirectoryCount: Int {
        max(0, filteredDirectoryGroups.count - visibleDirectoryGroups.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        TextField(
                            displayMode == .directories ? "Filter directories in this section" : "Filter files in this section",
                            text: $searchText
                        )
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: searchText) { _ in
                            visibleCount = Self.pageSize
                            expandedDirectoryVisibleCount = Self.pageSize
                        }

                        Picker("Sort", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        .onChange(of: sortOption) { _ in
                            visibleCount = Self.pageSize
                            expandedDirectoryVisibleCount = Self.pageSize
                        }
                    }
                    .padding(.bottom, 4)

                    if displayMode == .directories {
                        ForEach(visibleDirectoryGroups) { group in
                            DirectoryGroupRowView(
                                group: group,
                                riskColor: riskColor,
                                isExpanded: expandedDirectoryPath == group.path,
                                onToggle: {
                                    if expandedDirectoryPath == group.path {
                                        expandedDirectoryPath = nil
                                    } else {
                                        expandedDirectoryPath = group.path
                                        expandedDirectoryVisibleCount = Self.pageSize
                                    }
                                }
                            )

                            if expandedDirectoryPath == group.path {
                                directoryFilesView(for: group.path)
                            }
                        }
                    } else {
                        ForEach(visibleFiles) { file in
                            FileRowView(file: file)
                        }
                    }

                    paginationFooter
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

    @ViewBuilder
    private var paginationFooter: some View {
        if displayMode == .directories {
            if filteredDirectoryGroups.isEmpty {
                Text("No directories match this filter.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else if remainingDirectoryCount > 0 {
                HStack {
                    Text("Showing \(visibleDirectoryGroups.count) of \(filteredDirectoryGroups.count) directories")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Show \(min(Self.pageSize, remainingDirectoryCount)) More") {
                        visibleCount += Self.pageSize
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        } else if filteredFiles.isEmpty {
            Text("No files match this filter.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        } else if remainingFileCount > 0 {
            HStack {
                Text("Showing \(visibleFiles.count) of \(filteredFiles.count) files")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Show \(min(Self.pageSize, remainingFileCount)) More") {
                    visibleCount += Self.pageSize
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
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

    @ViewBuilder
    private func directoryFilesView(for directoryPath: String) -> some View {
        let matchingFiles = filteredFiles.filter { parentDirectory(for: $0.path) == directoryPath }
        let visibleDirectoryFiles = matchingFiles.prefix(expandedDirectoryVisibleCount)
        let remainingDirectoryFiles = max(0, matchingFiles.count - visibleDirectoryFiles.count)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(visibleDirectoryFiles) { file in
                FileRowView(file: file)
            }

            if remainingDirectoryFiles > 0 {
                HStack {
                    Text("Showing \(visibleDirectoryFiles.count) of \(matchingFiles.count) files in this directory")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Show \(min(Self.pageSize, remainingDirectoryFiles)) More") {
                        expandedDirectoryVisibleCount += Self.pageSize
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(.leading, 28)
        .padding(.bottom, 6)
    }
}

private struct DirectoryGroupRowView: View {
    let group: RiskLevelSection.DirectoryGroup
    let riskColor: Color
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(riskColor)
                    .frame(width: 20)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(group.name)
                            .font(.caption)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(group.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(group.fileCount) files", systemImage: "doc.on.doc")
                        Label(group.formattedModified, systemImage: "clock")
                        Text(group.sampleReasons)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.9))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(spacing: 6) {
                        Button("Open") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: group.path))
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)

                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(group.path, forType: .string)
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                    }
                    .foregroundColor(.accentColor)

                    Text(group.formattedSize)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(isExpanded ? 0.06 : 0.03))
        )
    }
}
