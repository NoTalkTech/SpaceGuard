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
    func estimatedSavings(using estimator: SpaceEstimator = SpaceEstimator()) -> Int64 {
        return estimator.estimateSpace(for: includedScenarios)
    }

    /// 获取格式化的预估节省空间
    func formattedSavings(using estimator: SpaceEstimator = SpaceEstimator()) -> String {
        let savings = estimatedSavings(using: estimator)
        return formatBytes(savings)
    }
}

/// 预设管理器
public class CleanupPresetManager {

    private let userDefaults = UserDefaults.standard
    private let estimator = SpaceEstimator()

    /// 获取预设对应的规则配置
    func getPresetRules(_ preset: CleanupPreset) -> CleanupRules {
        var rules = CleanupRules()

        switch preset {
        case .safe:
            // 安全预设：保守设置
            rules.autoCleanLowRisk = true
            rules.confirmMediumRisk = true
            rules.neverDeleteHighRisk = true
            rules.deleteDownloadsOlderThanDays = 180 // 6个月
            rules.deleteLogsOlderThanDays = 60
            rules.deleteCacheOlderThanDays = 30
            rules.minimumFileSizeToConsider = 1024 * 1024 // 1MB
            rules.skipFilesLargerThan = 5 * 1024 * 1024 * 1024 // 5GB

        case .developer:
            // 开发者预设：侧重开发工具
            rules.autoCleanLowRisk = true
            rules.confirmMediumRisk = false // 开发者通常不需要确认
            rules.neverDeleteHighRisk = true
            rules.deleteDownloadsOlderThanDays = 90 // 3个月
            rules.deleteLogsOlderThanDays = 14
            rules.deleteCacheOlderThanDays = 7
            rules.minimumFileSizeToConsider = 512 * 1024 // 512KB
            rules.skipFilesLargerThan = 2 * 1024 * 1024 * 1024 // 2GB

            // 包含更多开发工具缓存
            rules.appCachesToClean.append(contentsOf: [
                "com.microsoft.VSCode",
                "com.sublimetext.3",
                "com.vscodium",
                "org.vim.MacVim",
                "com.macromates.TextMate",
                "com.panic.Coda",
                "com.barebones.bbedit"
            ])

        case .advanced:
            // 高级预设：全面清理
            rules.autoCleanLowRisk = true
            rules.confirmMediumRisk = true
            rules.neverDeleteHighRisk = false // 高级用户可处理高风险
            rules.deleteDownloadsOlderThanDays = 30
            rules.deleteLogsOlderThanDays = 7
            rules.deleteCacheOlderThanDays = 3
            rules.minimumFileSizeToConsider = 128 * 1024 // 128KB
            rules.skipFilesLargerThan = 10 * 1024 * 1024 * 1024 // 10GB

            // 包含系统缓存位置
            rules.includeLocations.append(contentsOf: [
                "/var/folders", // 系统临时文件
                "/private/var/folders",
                "/private/tmp"
            ])

        case .custom:
            // 自定义预设：加载用户保存的设置
            if let savedData = userDefaults.data(forKey: "customPresetRules"),
               let savedRules = try? JSONDecoder().decode(CleanupRules.self, from: savedData) {
                rules = savedRules
            }
        }

        return rules
    }

    /// 将预设应用到现有规则
    func applyPreset(_ preset: CleanupPreset, to existingRules: CleanupRules) -> CleanupRules {
        let presetRules = getPresetRules(preset)
        var mergedRules = existingRules

        // 合并基本设置（预设优先）
        mergedRules.autoCleanLowRisk = presetRules.autoCleanLowRisk
        mergedRules.confirmMediumRisk = presetRules.confirmMediumRisk
        mergedRules.neverDeleteHighRisk = presetRules.neverDeleteHighRisk

        // 合并年龄阈值（取较小值，即更积极的清理）
        mergedRules.deleteDownloadsOlderThanDays = min(
            existingRules.deleteDownloadsOlderThanDays,
            presetRules.deleteDownloadsOlderThanDays
        )
        mergedRules.deleteLogsOlderThanDays = min(
            existingRules.deleteLogsOlderThanDays,
            presetRules.deleteLogsOlderThanDays
        )
        mergedRules.deleteCacheOlderThanDays = min(
            existingRules.deleteCacheOlderThanDays,
            presetRules.deleteCacheOlderThanDays
        )

        // 合并大小阈值（取较小值，即考虑更小的文件）
        mergedRules.minimumFileSizeToConsider = min(
            existingRules.minimumFileSizeToConsider,
            presetRules.minimumFileSizeToConsider
        )
        mergedRules.skipFilesLargerThan = min(
            existingRules.skipFilesLargerThan,
            presetRules.skipFilesLargerThan
        )

        // 合并位置（去重）
        let combinedIncludes = Array(Set(existingRules.includeLocations + presetRules.includeLocations))
        mergedRules.includeLocations = combinedIncludes.sorted()

        let combinedExcludes = Array(Set(existingRules.excludeLocations + presetRules.excludeLocations))
        mergedRules.excludeLocations = combinedExcludes.sorted()

        // 合并应用缓存（去重）
        let combinedAppCaches = Array(Set(existingRules.appCachesToClean + presetRules.appCachesToClean))
        mergedRules.appCachesToClean = combinedAppCaches.sorted()

        // 记录应用的预设
        if !mergedRules.appliedPresets.contains(preset) {
            mergedRules.appliedPresets.append(preset)
        }

        return mergedRules
    }

    /// 保存自定义预设
    func saveCustomPreset(_ rules: CleanupRules, name: String? = nil) throws {
        let presetName = name ?? "自定义预设 \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"

        // 创建自定义预设记录
        let customPreset = CustomPreset(
            id: UUID(),
            name: presetName,
            rules: rules,
            createdDate: Date(),
            lastUsedDate: Date()
        )

        // 加载现有自定义预设
        var customPresets = loadCustomPresets()
        customPresets.append(customPreset)

        // 保存到UserDefaults
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(customPresets)
        userDefaults.set(data, forKey: "customPresets")
    }

    /// 加载所有自定义预设
    func loadCustomPresets() -> [CustomPreset] {
        guard let data = userDefaults.data(forKey: "customPresets"),
              let presets = try? JSONDecoder().decode([CustomPreset].self, from: data) else {
            return []
        }
        return presets.sorted { $0.lastUsedDate > $1.lastUsedDate } // 按最后使用时间排序
    }

    /// 删除自定义预设
    func deleteCustomPreset(_ preset: CustomPreset) throws {
        var customPresets = loadCustomPresets()
        customPresets.removeAll { $0.id == preset.id }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(customPresets)
        userDefaults.set(data, forKey: "customPresets")
    }

    /// 获取预设的预估节省空间报告
    func getPresetSavingsReport(_ preset: CleanupPreset) -> PresetSavingsReport {
        let rules = getPresetRules(preset)
        let totalSavings = estimator.estimateSpaceForRules(rules)
        let scenarioSavings = estimator.estimateSpace(for: preset.includedScenarios)

        return PresetSavingsReport(
            preset: preset,
            totalSavings: totalSavings,
            formattedTotalSavings: formatBytes(totalSavings),
            scenarioSavings: scenarioSavings,
            formattedScenarioSavings: formatBytes(scenarioSavings),
            ruleBasedSavings: totalSavings - scenarioSavings,
            timestamp: Date()
        )
    }

    /// 获取所有预设的节省空间比较
    func compareAllPresets() -> [PresetComparison] {
        return CleanupPreset.allCases.map { preset in
            let report = getPresetSavingsReport(preset)
            return PresetComparison(
                preset: preset,
                savings: report.totalSavings,
                formattedSavings: report.formattedTotalSavings,
                scenarioCount: preset.includedScenarios.count,
                riskLevel: calculatePresetRiskLevel(preset)
            )
        }.sorted { $0.savings > $1.savings } // 按节省空间降序排序
    }

    /// 计算预设的风险等级
    private func calculatePresetRiskLevel(_ preset: CleanupPreset) -> RiskLevel {
        switch preset {
        case .safe:
            return .low
        case .developer:
            return .medium
        case .advanced:
            return .medium // 高级但仍有保护措施
        case .custom:
            return .medium // 自定义预设风险中等（用户自定义规则）
        }
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

