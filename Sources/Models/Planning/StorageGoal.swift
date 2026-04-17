import Foundation

struct StorageGoal: Codable, Equatable {
    var minimumFreeBytes: Int64 = 80 * 1024 * 1024 * 1024
    var minimumFreePercent: Double = 0.15

    func targetFreeBytes(for stats: DiskStats) -> Int64 {
        let percentTarget = Int64(Double(stats.total) * minimumFreePercent)
        return max(minimumFreeBytes, percentTarget)
    }
}
