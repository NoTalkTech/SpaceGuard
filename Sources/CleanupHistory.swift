import Foundation

// MARK: - Cleanup Operation Type
enum CleanupType: String, Codable, CaseIterable {
    case quick = "Quick Cleanup"
    case full = "Full Cleanup"
    case scheduled = "Scheduled Cleanup"
    case scenario = "Scenario Cleanup"
    case manual = "Manual Selection"

    var colorHex: String {
        switch self {
        case .quick: return "#FFD700"
        case .full: return "#FF6B6B"
        case .scheduled: return "#9B59B6"
        case .scenario: return "#3498DB"
        case .manual: return "#2ECC71"
        }
    }
}

// MARK: - Cleanup History Record
struct CleanupHistoryRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let cleanupType: CleanupType
    let filesDeleted: Int
    let spaceFreed: Int64
    let duration: TimeInterval
    let errors: Int
    let wasCancelled: Bool

    var formattedSpaceFreed: String {
        ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file)
    }

    var formattedDuration: String {
        if duration < 60 {
            return String(format: "%.1f seconds", duration)
        } else {
            let minutes = Int(duration / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: timestamp)
    }

    var iconName: String {
        switch cleanupType {
        case .quick: return "bolt.fill"
        case .full: return "trash.fill"
        case .scheduled: return "clock.fill"
        case .scenario: return "checklist"
        case .manual: return "hand.tap.fill"
        }
    }

    var iconColorHex: String {
        cleanupType.colorHex
    }
}

// MARK: - Cleanup Statistics
struct CleanupStatistics {
    let totalCleanups: Int
    let totalFilesDeleted: Int
    let totalSpaceFreed: Int64
    let averageFilesPerCleanup: Double
    let averageSpacePerCleanup: Int64
    let weeklyData: [WeeklyStat]
    let cleanupTypeDistribution: [CleanupTypeDistribution]

    struct WeeklyStat: Identifiable {
        let id = UUID()
        let weekStart: Date
        let filesDeleted: Int
        let spaceFreed: Int64
    }

    struct CleanupTypeDistribution: Identifiable {
        let id = UUID()
        let type: CleanupType
        let count: Int
        let percentage: Double
    }

    var formattedTotalSpaceFreed: String {
        ByteCountFormatter.string(fromByteCount: totalSpaceFreed, countStyle: .file)
    }

    var formattedAverageSpace: String {
        ByteCountFormatter.string(fromByteCount: averageSpacePerCleanup, countStyle: .file)
    }
}
