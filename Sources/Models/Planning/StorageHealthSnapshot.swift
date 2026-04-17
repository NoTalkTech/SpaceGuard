import Foundation

enum StorageHealthLevel: String, Codable {
    case safe
    case warning
    case urgent
}

struct StorageHealthSnapshot: Codable, Equatable {
    let capturedAt: Date
    let diskStats: DiskStats
    let goal: StorageGoal
    let targetFreeBytes: Int64
    let gapToTargetBytes: Int64
    let level: StorageHealthLevel

    var projectedFreePercentage: Double {
        guard diskStats.total > 0 else { return 0 }
        return Double(targetFreeBytes) / Double(diskStats.total) * 100
    }
}
