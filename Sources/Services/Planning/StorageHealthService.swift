import Foundation

struct StorageHealthService: StorageHealthProviding {
    func makeSnapshot(stats: DiskStats, goal: StorageGoal) -> StorageHealthSnapshot {
        let targetFreeBytes = goal.targetFreeBytes(for: stats)
        let gapToTargetBytes = max(0, targetFreeBytes - stats.free)

        let level: StorageHealthLevel
        if gapToTargetBytes == 0 {
            level = .safe
        } else if stats.free >= targetFreeBytes / 2 {
            level = .warning
        } else {
            level = .urgent
        }

        return StorageHealthSnapshot(
            capturedAt: Date(),
            diskStats: stats,
            goal: goal,
            targetFreeBytes: targetFreeBytes,
            gapToTargetBytes: gapToTargetBytes,
            level: level
        )
    }
}
