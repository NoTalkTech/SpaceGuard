import Foundation
import SwiftUI

// MARK: - Cleanup History Manager
@MainActor
class CleanupHistoryManager: ObservableObject {
    static let shared = CleanupHistoryManager()

    @Published var records: [CleanupHistoryRecord] = []

    private let userDefaults = UserDefaults.standard
    private let historyKey = "cleanupHistory"
    private let maxRecords = 100

    private init() {}

    // MARK: - Persistence

    private func loadHistory() -> [CleanupHistoryRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([CleanupHistoryRecord].self, from: data) else {
            return []
        }
        return history.sorted { $0.timestamp > $1.timestamp }
    }

    private func saveHistory(_ history: [CleanupHistoryRecord]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }

    // MARK: - CRUD Operations

    func load() {
        records = loadHistory()
    }

    func addRecord(_ record: CleanupHistoryRecord) {
        records.insert(record, at: 0)

        // // Trim to max records
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }

        saveHistory(records)
    }

    func deleteRecord(_ record: CleanupHistoryRecord) {
        records.removeAll { $0.id == record.id }
        saveHistory(records)
    }

    func clearHistory() {
        records.removeAll()
        userDefaults.removeObject(forKey: historyKey)
    }

    // MARK: - Statistics Generation

    func generateStatistics() -> CleanupStatistics {
        let history = loadHistory()

        let totalCleanups = history.count
        let totalFilesDeleted = history.reduce(0) { $0 + $1.filesDeleted }
        let totalSpaceFreed = history.reduce(0) { $0 + $1.spaceFreed }

        let averageFilesPerCleanup = totalCleanups > 0 ? Double(totalFilesDeleted) / Double(totalCleanups) : 0
        let averageSpacePerCleanup = totalCleanups > 0 ? totalSpaceFreed / Int64(totalCleanups) : 0

        let weeklyData = generateWeeklyData(from: history)
        let typeDistribution = generateTypeDistribution(from: history, total: totalCleanups)

        return CleanupStatistics(
            totalCleanups: totalCleanups,
            totalFilesDeleted: totalFilesDeleted,
            totalSpaceFreed: totalSpaceFreed,
            averageFilesPerCleanup: averageFilesPerCleanup,
            averageSpacePerCleanup: averageSpacePerCleanup,
            weeklyData: weeklyData,
            cleanupTypeDistribution: typeDistribution
        )
    }

    private func generateWeeklyData(from history: [CleanupHistoryRecord]) -> [CleanupStatistics.WeeklyStat] {
        let calendar = Calendar.current
        var weeklyStats: [Date: (files: Int, space: Int64)] = [:]

        for record in history {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: record.timestamp))!
            let current = weeklyStats[weekStart] ?? (0, 0)
            weeklyStats[weekStart] = (current.files + record.filesDeleted, current.space + record.spaceFreed)
        }

        return weeklyStats
            .sorted { $0.key < $1.key }
            .suffix(12) // Last 12 weeks
            .map { weekStart, data in
                CleanupStatistics.WeeklyStat(
                    weekStart: weekStart,
                    filesDeleted: data.files,
                    spaceFreed: data.space
                )
            }
    }

    private func generateTypeDistribution(from history: [CleanupHistoryRecord], total: Int) -> [CleanupStatistics.CleanupTypeDistribution] {
        var counts: [CleanupType: Int] = [:]

        for type in CleanupType.allCases {
            counts[type] = 0
        }

        for record in history {
            counts[record.cleanupType, default: 0] += 1
        }

        return counts.map { type, count in
            CleanupStatistics.CleanupTypeDistribution(
                type: type,
                count: count,
                percentage: total > 0 ? Double(count) / Double(total) * 100 : 0
            )
        }
        .filter { $0.count > 0 }
        .sorted { $0.count > $1.count }
    }
}
