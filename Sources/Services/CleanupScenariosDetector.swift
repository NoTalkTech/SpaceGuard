import Foundation

/// 场景检测器
class CleanupScenariosDetector {

    private let fileManager = FileManager.default
    private let installerExtensions = Set(["dmg", "pkg", "zip"])
    private let installerAgeThresholdDays = 30

    /// 检测所有场景
    func detectAllScenarios() -> [ScenarioDetectionResult] {
        return CleanupScenario.allCases.map { detectScenario($0) }
    }

    /// 检测特定场景
    func detectScenario(_ scenario: CleanupScenario) -> ScenarioDetectionResult {
        if scenario == .downloadInstallers {
            return detectDownloadInstallersScenario()
        }

        var detectedPaths: [String] = []
        var totalSize: Int64 = 0
        var lastModified: Date? = nil

        for pattern in scenario.pathPatterns {
            let paths = expandPathPattern(pattern)
            for path in paths {
                if fileManager.fileExists(atPath: path) {
                    detectedPaths.append(path)

                    // 命令型场景使用粗估值，避免遍历大型目录（例如 Homebrew Cellar）
                    if !scenario.usesCommandLine {
                        if let size = calculateDirectorySize(path) {
                            totalSize += size
                        }
                    }

                    // 获取最后修改时间
                    if let attributes = try? fileManager.attributesOfItem(atPath: path),
                       let modDate = attributes[.modificationDate] as? Date {
                        if lastModified == nil || modDate > lastModified! {
                            lastModified = modDate
                        }
                    }
                }
            }
        }

        // 对于命令行清理的场景，使用粗略估计而不是扫描整个目录树。
        if scenario.usesCommandLine {
            totalSize = estimateCommandCleanupSpace(scenario)
        }

        return ScenarioDetectionResult(
            scenario: scenario,
            detected: !detectedPaths.isEmpty || (scenario.usesCommandLine && totalSize > 0),
            estimatedSpace: totalSize,
            detectedPaths: detectedPaths,
            lastModified: lastModified
        )
    }

    /// 检测给定路径属于哪个场景
    func detectScenario(at path: String) -> CleanupScenario? {
        for scenario in CleanupScenario.allCases {
            for pattern in scenario.pathPatterns {
                if matchesPathPattern(pattern, path: path) {
                    return scenario
                }
            }
        }
        return nil
    }

    /// 获取场景详情
    func getScenarioDetails(_ scenario: CleanupScenario) -> (description: String, riskExplanation: String) {
        let description = scenario.description
        let riskExplanation: String

        switch scenario {
        case .trash:
            riskExplanation = "废纸篓中的文件是用户明确删除的，清理风险极低。"
        case .downloadInstallers:
            riskExplanation = "下载目录中的旧安装包通常可以重新下载，但仍需要用户主动确认。"
        case .wallpaperCache:
            riskExplanation = "壁纸缓存是系统自动下载的视频文件，删除后需要时会重新下载。"
        case .jetbrainsCache, .jetbrainsLogs:
            riskExplanation = "IDE 缓存和日志可以安全清理，但可能导致下次启动时重建索引。"
        case .shipItCache:
            riskExplanation = "Electron 更新缓存是应用更新过程的临时文件，可安全删除。"
        case .homebrewCache, .npmCache, .pipCache:
            riskExplanation = "包管理器缓存包含已下载的包文件，清理后需要时会重新下载。"
        }

        return (description, riskExplanation)
    }

    /// 预估场景可释放空间（更精确的估算）
    func estimateSpaceForScenario(_ scenario: CleanupScenario) -> Int64 {
        let result = detectScenario(scenario)
        return result.estimatedSpace
    }

    // MARK: - 私有辅助方法

    private func detectDownloadInstallersScenario() -> ScenarioDetectionResult {
        let downloadsPath = NSHomeDirectory() + "/Downloads"
        let downloadsURL = URL(fileURLWithPath: downloadsPath)

        guard let files = try? fileManager.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ScenarioDetectionResult(
                scenario: .downloadInstallers,
                detected: false,
                estimatedSpace: 0,
                detectedPaths: [],
                lastModified: nil
            )
        }

        var detectedPaths: [String] = []
        var totalSize: Int64 = 0
        var lastModified: Date?

        for fileURL in files {
            guard let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]),
                  values.isDirectory != true else {
                continue
            }

            let fileExtension = fileURL.pathExtension.lowercased()
            guard installerExtensions.contains(fileExtension) else { continue }

            let modifiedDate = values.contentModificationDate ?? .distantFuture
            guard daysSince(modifiedDate) >= installerAgeThresholdDays else { continue }

            detectedPaths.append(fileURL.path)
            totalSize += Int64(values.fileSize ?? 0)

            if lastModified == nil || modifiedDate > lastModified! {
                lastModified = modifiedDate
            }
        }

        return ScenarioDetectionResult(
            scenario: .downloadInstallers,
            detected: !detectedPaths.isEmpty,
            estimatedSpace: totalSize,
            detectedPaths: detectedPaths.sorted(),
            lastModified: lastModified
        )
    }

    private func expandPathPattern(_ pattern: String) -> [String] {
        if pattern.contains("*") {
            // 简单的通配符扩展
            let directory = (pattern as NSString).deletingLastPathComponent
            let filePattern = (pattern as NSString).lastPathComponent

            guard let enumerator = fileManager.enumerator(atPath: directory) else {
                return []
            }

            var paths: [String] = []
            while let file = enumerator.nextObject() as? String {
                if matchesSimplePattern(filePattern, fileName: file) {
                    paths.append((directory as NSString).appendingPathComponent(file))
                }
            }
            return paths
        } else {
            return [pattern]
        }
    }

    private func matchesSimplePattern(_ pattern: String, fileName: String) -> Bool {
        // 简单的通配符匹配（仅支持末尾通配符）
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return fileName.hasPrefix(prefix)
        }
        return fileName == pattern
    }

    private func matchesPathPattern(_ pattern: String, path: String) -> Bool {
        if pattern.contains("*") {
            // 使用简单的字符串匹配
            let patternParts = pattern.split(separator: "/")
            let pathParts = path.split(separator: "/")

            if patternParts.count != pathParts.count {
                return false
            }

            for (patternPart, pathPart) in zip(patternParts, pathParts) {
                if patternPart.contains("*") {
                    if !String(pathPart).hasPrefix(patternPart.replacingOccurrences(of: "*", with: "")) {
                        return false
                    }
                } else if patternPart != pathPart {
                    return false
                }
            }
            return true
        } else {
            return path.hasPrefix(pattern)
        }
    }

    private func calculateDirectorySize(_ path: String) -> Int64? {
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return nil
        }

        for case let file as String in enumerator {
            let fullPath = (path as NSString).appendingPathComponent(file)
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                if let fileSize = attributes[.size] as? NSNumber {
                    totalSize += fileSize.int64Value
                }
            } catch {
                // 忽略无法访问的文件
                continue
            }
        }

        return totalSize
    }

    private func estimateCommandCleanupSpace(_ scenario: CleanupScenario) -> Int64 {
        // 对于命令行清理，提供粗略估计
        switch scenario {
        case .homebrewCache:
            return 500 * 1024 * 1024 // 估计 500MB
        case .npmCache:
            return 200 * 1024 * 1024 // 估计 200MB
        case .pipCache:
            return 100 * 1024 * 1024 // 估计 100MB
        default:
            return 0
        }
    }

    private func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

/// 格式化字节数为易读格式
func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
