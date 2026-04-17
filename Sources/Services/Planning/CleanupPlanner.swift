import Foundation

struct CleanupPlanner: CleanupPlanning {
    private let healthProvider: StorageHealthProviding

    init(healthProvider: StorageHealthProviding = StorageHealthService()) {
        self.healthProvider = healthProvider
    }

    func makePlan(
        stats: DiskStats,
        rules: CleanupRules,
        scenarioResults: [ScenarioDetectionResult],
        goal: StorageGoal
    ) -> CleanupPlan {
        let health = healthProvider.makeSnapshot(stats: stats, goal: goal)
        let items = scenarioResults
            .filter { $0.detected && $0.estimatedSpace > 0 }
            .map { makeItem(for: $0, rules: rules) }
            .sorted(by: compareItems)

        let totalEstimatedSavingsBytes = items.reduce(0) { $0 + $1.estimatedSavingsBytes }
        let selectedEstimatedSavingsBytes = items
            .filter(\.defaultSelected)
            .reduce(0) { $0 + $1.estimatedSavingsBytes }
        let projectedFreeBytes = min(stats.total, stats.free + selectedEstimatedSavingsBytes)
        let projectedGapToTargetBytes = max(0, health.targetFreeBytes - projectedFreeBytes)

        return CleanupPlan(
            createdAt: Date(),
            health: health,
            items: items,
            totalEstimatedSavingsBytes: totalEstimatedSavingsBytes,
            selectedEstimatedSavingsBytes: selectedEstimatedSavingsBytes,
            projectedFreeBytes: projectedFreeBytes,
            projectedGapToTargetBytes: projectedGapToTargetBytes,
            reachesGoal: projectedGapToTargetBytes == 0
        )
    }

    private func makeItem(for result: ScenarioDetectionResult, rules: CleanupRules) -> CleanupPlanItem {
        let recommendation = recommendation(for: result.scenario)
        let defaultSelected = result.scenario.defaultRiskLevel == .low && rules.autoCleanLowRisk
        let actionType: CleanupActionType = result.scenario == .downloadInstallers ? .fileSelection : .scenarioExecution

        return CleanupPlanItem(
            id: UUID(),
            source: .scenario,
            title: result.scenario.displayName,
            summary: result.scenario.description,
            estimatedSavingsBytes: result.estimatedSpace,
            riskLevel: result.scenario.defaultRiskLevel,
            recoveryCost: recommendation.recoveryCost,
            regenerability: recommendation.regenerability,
            recommended: recommendation.recommended,
            defaultSelected: defaultSelected,
            actionType: actionType,
            backingScenario: result.scenario,
            backingPaths: result.detectedPaths,
            recommendationReason: recommendation.reason
        )
    }

    private func compareItems(_ lhs: CleanupPlanItem, _ rhs: CleanupPlanItem) -> Bool {
        if lhs.defaultSelected != rhs.defaultSelected {
            return lhs.defaultSelected && !rhs.defaultSelected
        }

        if lhs.recommended != rhs.recommended {
            return lhs.recommended && !rhs.recommended
        }

        let lhsPriority = recommendationPriority(for: lhs.backingScenario)
        let rhsPriority = recommendationPriority(for: rhs.backingScenario)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        if lhs.riskLevel != rhs.riskLevel {
            return riskRank(lhs.riskLevel) < riskRank(rhs.riskLevel)
        }

        return lhs.estimatedSavingsBytes > rhs.estimatedSavingsBytes
    }

    private func riskRank(_ riskLevel: RiskLevel) -> Int {
        switch riskLevel {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    private func recommendationPriority(for scenario: CleanupScenario?) -> Int {
        guard let scenario else { return Int.max }

        switch scenario {
        case .trash:
            return 1
        case .downloadInstallers:
            return 3
        case .wallpaperCache, .shipItCache:
            return 2
        case .jetbrainsLogs:
            return 3
        case .jetbrainsCache, .homebrewCache, .npmCache, .pipCache:
            return 4
        }
    }

    private func recommendation(for scenario: CleanupScenario) -> (
        recommended: Bool,
        recoveryCost: RecoveryCost,
        regenerability: Regenerability,
        reason: String
    ) {
        switch scenario {
        case .trash:
            return (true, .low, .nonRegenerable, "用户已删除内容，清空后通常能立即回收空间")
        case .downloadInstallers:
            return (true, .medium, .regenerable, "下载目录中的旧安装包通常可重新下载，适合作为确认后清理项")
        case .wallpaperCache:
            return (true, .low, .regenerable, "系统媒体缓存可重新下载，适合作为低风险释放空间项")
        case .jetbrainsCache:
            return (true, .medium, .regenerable, "IDE 缓存可重建，适合开发者优先的推荐方案")
        case .jetbrainsLogs:
            return (true, .low, .regenerable, "日志文件不影响核心数据，适合优先清理")
        case .shipItCache:
            return (true, .low, .regenerable, "更新缓存属于临时资源，删除后需要时会重新生成")
        case .homebrewCache:
            return (true, .medium, .regenerable, "包管理器缓存可重新下载，通常能安全释放空间")
        case .npmCache:
            return (true, .medium, .regenerable, "npm 缓存是开发高频占用项，清理后可重建")
        case .pipCache:
            return (true, .medium, .regenerable, "pip 缓存可以重新下载，适合纳入开发者清理方案")
        }
    }
}
