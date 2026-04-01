import SwiftUI

struct CleanupStatisticsView: View {
    @ObservedObject private var historyManager = CleanupHistoryManager.shared

    private var statistics: CleanupStatistics? {
        if historyManager.records.isEmpty {
            return nil
        }
        return historyManager.generateStatistics()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Content
            if let stats = statistics {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Overview cards
                        overviewSection(stats: stats)

                        Divider()

                        // Space freed chart
                        spaceChartSection(stats: stats)

                        Divider()

                        // Cleanup by type
                        typeDistributionSection(stats: stats)
                    }
                    .padding()
                }
            } else {
                emptyState
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Cleanup Statistics")
                .font(.headline)

            Spacer()

            Button("Refresh") {
                historyManager.load()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Statistics Yet")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Complete some cleanups to see statistics")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func overviewSection(stats: CleanupStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatsCard(
                    title: "Total Cleanups",
                    value: "\(stats.totalCleanups)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
                StatsCard(
                    title: "Files Deleted",
                    value: "\(stats.totalFilesDeleted)",
                    icon: "doc.fill",
                    color: .orange
                )
                StatsCard(
                    title: "Space Freed",
                    value: stats.formattedTotalSpaceFreed,
                    icon: "internaldrive.fill",
                    color: .green
                )
                StatsCard(
                    title: "Avg. Space/Cleanup",
                    value: stats.formattedAverageSpace,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }
        }
    }

    private func spaceChartSection(stats: CleanupStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Space Freed Over Time")
                .font(.headline)

            if stats.weeklyData.isEmpty {
                Text("No weekly data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                BarChartView(data: stats.weeklyData)
                    .frame(height: 200)
            }
        }
    }

    private func typeDistributionSection(stats: CleanupStatistics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanups by Type")
                .font(.headline)

            if stats.cleanupTypeDistribution.isEmpty {
                Text("No data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                CleanupTypeDistributionView(data: stats.cleanupTypeDistribution)
            }
        }
    }
}

// MARK: - Supporting Views
struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold))

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct BarChartView: View {
    let data: [CleanupStatistics.WeeklyStat]

    private var sortedData: [CleanupStatistics.WeeklyStat] {
        data.sorted { $0.weekStart < $1.weekStart }
    }

    private var maxValue: Int64 {
        data.map { $0.spaceFreed }.max() ?? 1
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(sortedData) { stat in
                    VStack(spacing: 4) {
                        let heightRatio = Double(stat.spaceFreed) / Double(maxValue)

                        Rectangle()
                            .fill(Color.green)
                            .frame(width: max(8, geometry.size.width / CGFloat(sortedData.count) - 4), height: max(2, heightRatio * 150))
                            .cornerRadius(4)

                        Text(shortDateFormatter.string(from: stat.weekStart))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var shortDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }
}

struct CleanupTypeDistributionView: View {
    let data: [CleanupStatistics.CleanupTypeDistribution]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(data) { item in
                HStack(spacing: 12) {
                    Circle()
                        .fill(color(for: item.type))
                        .frame(width: 12, height: 12)

                    Text(item.type.rawValue)
                        .font(.caption)
                        .frame(width: 120, alignment: .leading)

                    ProgressView(value: item.percentage / 100)
                        .tint(color(for: item.type))

                    Text("\(item.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
    }

    private func color(for type: CleanupType) -> Color {
        switch type {
        case .quick: return .yellow
        case .full: return .red
        case .scheduled: return .purple
        case .scenario: return .blue
        case .manual: return .green
        }
    }
}
