import Foundation

enum RiskLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var colorName: String {
        switch self {
        case .low: return "systemGreen"
        case .medium: return "systemOrange"
        case .high: return "systemRed"
        }
    }

    var description: String {
        switch self {
        case .low: return "Safe to delete automatically"
        case .medium: return "Confirm before deleting"
        case .high: return "Do not delete"
        }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let created: Date
    let modified: Date
    let riskLevel: RiskLevel
    let reason: String

    var name: String {
        url.lastPathComponent
    }

    var path: String {
        url.path
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedCreated: String {
        DateFormatter.localizedString(from: created, dateStyle: .short, timeStyle: .short)
    }

    var formattedModified: String {
        DateFormatter.localizedString(from: modified, dateStyle: .short, timeStyle: .short)
    }

    static func sample() -> [FileItem] {
        let date = Date()
        return [
            FileItem(
                url: URL(fileURLWithPath: "/Users/Test/Library/Caches/com.apple.Safari/Cache.db"),
                size: 1024 * 1024 * 150, // 150 MB
                created: date.addingTimeInterval(-86400 * 7), // 7 days ago
                modified: date.addingTimeInterval(-86400), // 1 day ago
                riskLevel: .low,
                reason: "Browser cache"
            ),
            FileItem(
                url: URL(fileURLWithPath: "/Users/Test/Downloads/old_file.zip"),
                size: 1024 * 1024 * 500, // 500 MB
                created: date.addingTimeInterval(-86400 * 90), // 90 days ago
                modified: date.addingTimeInterval(-86400 * 90),
                riskLevel: .medium,
                reason: "Old download (90+ days)"
            ),
            FileItem(
                url: URL(fileURLWithPath: "/System/Library/CoreServices/SystemAppearance.bundle"),
                size: 1024 * 1024 * 10, // 10 MB
                created: date.addingTimeInterval(-86400 * 365), // 1 year ago
                modified: date.addingTimeInterval(-86400 * 365),
                riskLevel: .high,
                reason: "System file"
            )
        ]
    }
}