import Foundation

// MARK: - Rule Conflict Structures

enum RuleConflictType: String, Codable {
    case pathInclusionExclusion = "Path inclusion/exclusion conflict"
    case fileTypeRule = "File type rule conflict"
    case customRiskOverride = "Custom risk override conflict"
    case ageThreshold = "Age threshold conflict"
    case sizeThreshold = "Size threshold conflict"
}

enum ConflictSeverity: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

struct RuleConflict: Identifiable, Codable {
    let id = UUID()
    let type: RuleConflictType
    let description: String
    let severity: ConflictSeverity

    enum CodingKeys: String, CodingKey {
        case type, description, severity
        // id is excluded from coding because it's auto-generated
    }
}

// MARK: - Advanced Rule Structures

struct FileTypeRules: Codable {
    var whitelistedExtensions: [String] = [] // Empty means all allowed
    var blacklistedExtensions: [String] = [".app", ".dmg", ".pkg", ".kext", ".component"]

    static let `default` = FileTypeRules()
}

struct CustomRiskOverride: Codable, Identifiable {
    let id = UUID()
    var path: String
    var riskLevel: RiskLevel

    enum CodingKeys: String, CodingKey {
        case path, riskLevel
    }
}

struct ScheduledCleanup: Codable {
    var enabled: Bool = false
    var frequency: CleanupFrequency = .weekly
    var timeOfDay: Date = Calendar.current.date(bySettingHour: 2, minute: 0, second: 0, of: Date()) ?? Date() // 2 AM
    var lastRun: Date?

    enum CleanupFrequency: String, Codable, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var timeInterval: TimeInterval {
            switch self {
            case .daily: return 86400 // 24 hours
            case .weekly: return 604800 // 7 days
            case .monthly: return 2592000 // 30 days
            }
        }
    }
}
