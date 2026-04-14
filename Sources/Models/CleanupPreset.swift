import Foundation

/// 清理预设枚举
public enum CleanupPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case safe = "safe"
    case developer = "developer"
    case advanced = "advanced"
    case custom = "custom"

    public var id: String { rawValue }

    /// 预设显示名称
    var displayName: String {
        switch self {
        case .safe: return "安全清理"
        case .developer: return "开发者清理"
        case .advanced: return "高级清理"
        case .custom: return "自定义"
        }
    }

    /// 预设描述
    var description: String {
        switch self {
        case .safe:
            return "仅清理低风险缓存和临时文件，适合大多数用户"
        case .developer:
            return "清理开发工具缓存（JetBrains、npm、pip等），适合开发者"
        case .advanced:
            return "全面清理包括废纸篓和系统缓存，适合高级用户"
        case .custom:
            return "用户自定义的清理规则"
        }
    }

    /// 预设包含的场景
    var includedScenarios: [CleanupScenario] {
        switch self {
        case .safe:
            return [.wallpaperCache, .shipItCache, .homebrewCache, .npmCache, .pipCache]
        case .developer:
            return [.jetbrainsCache, .jetbrainsLogs, .npmCache, .pipCache, .homebrewCache]
        case .advanced:
            return CleanupScenario.allCases // 所有场景
        case .custom:
            return [] // 自定义预设无默认场景
        }
    }

    /// 预设图标名称
    var iconName: String {
        switch self {
        case .safe: return "shield.checkered"
        case .developer: return "hammer"
        case .advanced: return "gearshape.2"
        case .custom: return "slider.horizontal.3"
        }
    }

    /// 预估节省空间（基于包含的场景）
    func estimatedSavings(using estimator: SpaceEstimating = SpaceEstimator()) -> Int64 {
        return estimator.estimateSpace(for: includedScenarios)
    }

    /// 获取格式化的预估节省空间
    func formattedSavings(using estimator: SpaceEstimating = SpaceEstimator()) -> String {
        let savings = estimatedSavings(using: estimator)
        return formatBytes(savings)
    }
}

/// 自定义预设记录
struct CustomPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var rules: CleanupRules
    var createdDate: Date
    var lastUsedDate: Date
    var description: String?
}

/// 预设节省空间报告
struct PresetSavingsReport {
    let preset: CleanupPreset
    let totalSavings: Int64
    let formattedTotalSavings: String
    let scenarioSavings: Int64
    let formattedScenarioSavings: String
    let ruleBasedSavings: Int64
    let timestamp: Date

    var hasSignificantSavings: Bool {
        return totalSavings > 500 * 1024 * 1024 // 大于500MB
    }

    var scenarioPercentage: Double {
        guard totalSavings > 0 else { return 0 }
        return Double(scenarioSavings) / Double(totalSavings) * 100
    }
}

/// 预设比较结果
struct PresetComparison: Identifiable {
    let id = UUID()
    let preset: CleanupPreset
    let savings: Int64
    let formattedSavings: String
    let scenarioCount: Int
    let riskLevel: RiskLevel

    var isRecommended: Bool {
        return preset == .safe || (preset == .developer && savings > 100 * 1024 * 1024)
    }
}
