import Foundation

/// 空间预估器 - 用于估算清理操作可释放的磁盘空间
class SpaceEstimator {

    private let detector = CleanupScenariosDetector()
    private let fileManager = FileManager.default

    /// 预估单个场景的可释放空间
    func estimateSpace(for scenario: CleanupScenario) -> Int64 {
        return detector.estimateSpaceForScenario(scenario)
    }

    /// 预估多个场景的总可释放空间
    func estimateSpace(for scenarios: [CleanupScenario]) -> Int64 {
        return scenarios.reduce(0) { $0 + estimateSpace(for: $1) }
    }

    /// 预估所有检测到的场景的总可释放空间
    func estimateTotalSavings() -> Int64 {
        let allResults = detector.detectAllScenarios()
        return allResults.reduce(0) { $0 + $1.estimatedSpace }
    }

    /// 获取按场景分类的空间预估明细
    func getDetailedEstimates() -> [(scenario: CleanupScenario, space: Int64, formatted: String)] {
        let allResults = detector.detectAllScenarios()
        return allResults.map {
            ($0.scenario, $0.estimatedSpace, formatBytes($0.estimatedSpace))
        }
    }

    /// 预估特定路径的可释放空间
    func estimateSpace(forPath path: String) -> Int64? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return nil
        }

        if isDirectory.boolValue {
            return calculateDirectorySize(path)
        } else {
            return getFileSize(path)
        }
    }

    /// 预估规则匹配文件的可释放空间
    func estimateSpaceForRules(_ rules: CleanupRules) -> Int64 {
        // TODO: 实现基于规则的详细空间预估
        // 这需要扫描所有包含位置的文件并应用规则过滤
        // 目前返回粗略估计

        let allResults = detector.detectAllScenarios()
        let scenarioSpace = allResults.reduce(0) { $0 + $1.estimatedSpace }

        // 基于包含位置的数量提供粗略乘数
        let locationMultiplier = Double(rules.includeLocations.count) / 5.0
        let estimatedRuleSpace = Int64(Double(scenarioSpace) * max(1.0, locationMultiplier))

        return estimatedRuleSpace
    }

    /// 格式化字节数为易读格式
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// 获取空间预估报告
    func generateReport() -> SpaceEstimationReport {
        let allResults = detector.detectAllScenarios()
        let totalSavings = allResults.reduce(0) { $0 + $1.estimatedSpace }
        let detectedScenarios = allResults.filter { $0.detected }.map { $0.scenario }

        let recommendations = generateRecommendations(from: allResults)

        return SpaceEstimationReport(
            totalSavings: totalSavings,
            formattedSavings: formatBytes(totalSavings),
            detectedScenarios: detectedScenarios,
            detailedResults: allResults,
            recommendations: recommendations,
            timestamp: Date()
        )
    }

    /// 生成清理建议
    private func generateRecommendations(from results: [ScenarioDetectionResult]) -> [CleanupRecommendation] {
        var recommendations: [CleanupRecommendation] = []

        for result in results where result.detected && result.estimatedSpace > 0 {
            let priority: Int
            let reason: String

            switch result.scenario {
            case .trash:
                priority = 1 // 最高优先级
                reason = "废纸篓通常包含用户已删除的文件，清理风险极低"
            case .wallpaperCache:
                priority = 2
                reason = "壁纸缓存是自动下载的媒体文件，可安全清理"
            case .jetbrainsCache, .jetbrainsLogs:
                priority = 3
                reason = "IDE 缓存和日志可清理，但可能导致索引重建"
            case .shipItCache:
                priority = 2
                reason = "应用更新缓存是临时文件，可安全删除"
            case .homebrewCache, .npmCache, .pipCache:
                priority = 4
                reason = "包管理器缓存可清理，但可能导致重新下载"
            }

            recommendations.append(CleanupRecommendation(
                scenario: result.scenario,
                priority: priority,
                reason: reason,
                estimatedSavings: result.estimatedSpace
            ))
        }

        // 按优先级和预估空间排序
        return recommendations.sorted {
            if $0.priority != $1.priority {
                return $0.priority < $1.priority
            }
            return $0.estimatedSavings > $1.estimatedSavings
        }
    }

    // MARK: - 私有辅助方法

    private func calculateDirectorySize(_ path: String) -> Int64 {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return 0
        }

        for case let file as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(file)
            totalSize += getFileSize(fullPath)
        }

        return totalSize
    }

    private func getFileSize(_ path: String) -> Int64 {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? NSNumber {
                return fileSize.int64Value
            }
        } catch {
            // 忽略无法访问的文件
        }
        return 0
    }
}

/// 空间预估报告
struct SpaceEstimationReport {
    let totalSavings: Int64
    let formattedSavings: String
    let detectedScenarios: [CleanupScenario]
    let detailedResults: [ScenarioDetectionResult]
    let recommendations: [CleanupRecommendation]
    let timestamp: Date

    var scenarioCount: Int {
        return detectedScenarios.count
    }

    var hasSignificantSavings: Bool {
        return totalSavings > 100 * 1024 * 1024 // 大于 100MB
    }

    var primaryRecommendation: CleanupRecommendation? {
        return recommendations.first
    }
}

/// 空间预估摘要（用于UI显示）
struct SpaceEstimationSummary {
    let totalSavings: Int64
    let formattedSavings: String
    let scenarioCount: Int
    let topScenario: CleanupScenario?
    let topScenarioSavings: Int64
    let formattedTopScenarioSavings: String
    let timestamp: Date

    static func fromReport(_ report: SpaceEstimationReport) -> SpaceEstimationSummary {
        let topScenarioResult = report.detailedResults
            .filter { $0.detected && $0.estimatedSpace > 0 }
            .max { $0.estimatedSpace < $1.estimatedSpace }

        return SpaceEstimationSummary(
            totalSavings: report.totalSavings,
            formattedSavings: report.formattedSavings,
            scenarioCount: report.scenarioCount,
            topScenario: topScenarioResult?.scenario,
            topScenarioSavings: topScenarioResult?.estimatedSpace ?? 0,
            formattedTopScenarioSavings: formatBytes(topScenarioResult?.estimatedSpace ?? 0),
            timestamp: report.timestamp
        )
    }
}

/// 扩展 CleanupScenariosDetector 以提供空间预估
extension CleanupScenariosDetector {
    /// 获取所有检测到的场景的空间预估摘要
    func getSpaceEstimationSummary() -> SpaceEstimationSummary {
        let estimator = SpaceEstimator()
        let report = estimator.generateReport()
        return SpaceEstimationSummary.fromReport(report)
    }
}