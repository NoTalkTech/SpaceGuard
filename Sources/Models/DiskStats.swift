import Foundation

struct DiskStats: Identifiable {
    let id = UUID()
    let total: Int64
    let used: Int64
    let free: Int64

    var usedPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    var freePercentage: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total) * 100
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: used, countStyle: .file)
    }

    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
    }

    var healthStatus: DiskHealth {
        let percentageUsed = usedPercentage

        switch percentageUsed {
        case 0..<70:
            return .good
        case 70..<85:
            return .warning
        case 85..<95:
            return .critical
        default:
            return .full
        }
    }

    static func sample() -> DiskStats {
        let total: Int64 = 1024 * 1024 * 1024 * 500 // 500 GB
        let used: Int64 = 1024 * 1024 * 1024 * 350 // 350 GB
        let free = total - used // 150 GB

        return DiskStats(total: total, used: used, free: free)
    }
}

enum DiskHealth: String {
    case good = "Good"
    case warning = "Warning"
    case critical = "Critical"
    case full = "Full"

    var colorName: String {
        switch self {
        case .good: return "systemGreen"
        case .warning: return "systemOrange"
        case .critical: return "systemRed"
        case .full: return "systemPurple"
        }
    }

    var description: String {
        switch self {
        case .good:
            return "Disk space is healthy"
        case .warning:
            return "Disk space is getting low"
        case .critical:
            return "Disk space is critically low"
        case .full:
            return "Disk is almost full"
        }
    }
}