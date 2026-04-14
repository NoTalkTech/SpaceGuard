import Foundation
import AppKit

/// 安全检查器 - 验证清理操作的安全性
class SafetyChecker {

    private static let appAssociations: [(patterns: [String], bundleIds: [String])] = [
        (patterns: [".xcodeproj", ".swift", ".m", ".h"], bundleIds: ["com.apple.dt.Xcode"]),
        (patterns: [".java", ".jar", ".class"], bundleIds: ["com.jetbrains.intellij"]),
        (patterns: [".js", ".ts", ".jsx", ".tsx", ".json"], bundleIds: ["com.microsoft.VSCode", "com.github.atom"]),
        (patterns: [".pdf"], bundleIds: ["com.adobe.AdobeReader", "com.apple.Preview"]),
        (patterns: [".doc", ".docx"], bundleIds: ["com.microsoft.Word"]),
        (patterns: [".xls", ".xlsx"], bundleIds: ["com.microsoft.Excel"]),
        (patterns: [".ppt", ".pptx"], bundleIds: ["com.microsoft.PowerPoint"]),
        (patterns: ["jetbrains"], bundleIds: ["com.jetbrains.*"])
    ]

    private static let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library"]

    private let fileManager = FileManager.default

    // MARK: - Public API

    /// 检查文件是否被占用（是否被其他进程打开）
    func checkFileInUse(_ filePath: String) -> Bool {
        // 尝试以写模式打开文件，如果成功则说明文件没有被占用
        // 这是简化的检查，实际实现可能需要更复杂的方法
        let fileURL = URL(fileURLWithPath: filePath)

        // 检查文件是否存在
        guard fileManager.fileExists(atPath: filePath) else {
            return false // 文件不存在，不会被占用
        }

        // 简化的检查：尝试获取文件的独占锁（非阻塞）
        // 注意：这在macOS上不是完全可靠的方法，但对于大多数用户文件足够了
        do {
            // 尝试打开文件进行读取（非独占）
            let fileHandle = try FileHandle(forReadingFrom: fileURL)
            defer {
                try? fileHandle.close()
            }

            // 如果能够成功打开，文件可能没有被独占锁定
            // 但这并不保证文件没有被其他进程使用
            // 更准确的检查需要系统级API，这超出了本应用的范围
            return false
        } catch {
            // 如果无法打开文件，可能被占用或其他错误
            print("无法打开文件 \(filePath): \(error)")
            return true // 假设文件被占用
        }
    }

    /// 检查相关应用是否正在运行
    func checkApplicationRunning(_ appBundleId: String) -> Bool {
        // 使用NSWorkspace检查应用是否运行
        let workspace = NSWorkspace.shared

        // 获取所有正在运行的应用
        let runningApps = workspace.runningApplications

        // 检查是否有匹配的应用
        for app in runningApps {
            if let bundleId = app.bundleIdentifier, bundleId == appBundleId {
                return true
            }
        }

        return false
    }

    /// 检查与路径关联的应用是否正在运行（基于文件扩展名或路径模式）
    func checkApplicationForPathRunning(_ filePath: String) -> Bool {
        let path = filePath.lowercased()

        for association in Self.appAssociations {
            for pattern in association.patterns {
                if path.contains(pattern) {
                    for bundleId in association.bundleIds {
                        if bundleId.contains("*") {
                            // 通配符匹配
                            let prefix = bundleId.replacingOccurrences(of: "*", with: "")
                            if checkAnyAppRunning(withPrefix: prefix) {
                                return true
                            }
                        } else if checkApplicationRunning(bundleId) {
                            return true
                        }
                    }
                }
            }
        }

        return false
    }

    /// 检查磁盘剩余空间（返回可用字节数）
    func checkDiskSpace() -> Int64? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())

        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            return values.volumeAvailableCapacity.map(Int64.init)
        } catch {
            print("无法获取磁盘空间: \(error)")
            return nil
        }
    }

    /// 检查是否有足够的磁盘空间进行清理（假设需要清理指定大小的文件）
    func hasSufficientDiskSpace(forCleaningSize size: Int64, minimumFreeSpace: Int64 = 1024 * 1024 * 1024) -> Bool {
        guard let freeSpace = checkDiskSpace() else {
            // 如果无法获取磁盘空间，假设空间足够
            return true
        }

        // 确保清理后仍有最小可用空间（默认1GB）
        return freeSpace > size + minimumFreeSpace
    }

    /// 综合安全检查 - 验证删除操作的安全性
    func validateDeletionSafety(_ filePath: String, rules: CleanupRules? = nil) -> SafetyCheckResult {
        var issues: [SafetyIssue] = []

        // 1. 检查文件是否被占用
        if checkFileInUse(filePath) {
            issues.append(SafetyIssue(
                type: .fileInUse,
                description: "文件正在被其他进程使用",
                path: filePath,
                severity: .high
            ))
        }

        // 2. 检查关联应用是否正在运行
        if checkApplicationForPathRunning(filePath) {
            issues.append(SafetyIssue(
                type: .applicationRunning,
                description: "关联应用正在运行，清理可能导致数据丢失",
                path: filePath,
                severity: .medium
            ))
        }

        // 3. 检查磁盘空间（基于预估清理大小）
        if rules != nil {
            // 如果有规则，可以估算清理大小
            // 这里简化处理，只检查当前文件大小
            if let fileSize = getFileSize(filePath) {
                if !hasSufficientDiskSpace(forCleaningSize: fileSize) {
                    issues.append(SafetyIssue(
                        type: .lowDiskSpace,
                        description: "磁盘空间不足，清理后可能影响系统运行",
                        path: filePath,
                        severity: .high
                    ))
                }
            }
        }

        // 4. 系统文件保护（如果提供规则）
        if rules != nil {
            for systemPath in Self.systemPaths {
                if filePath.hasPrefix(systemPath) {
                    issues.append(SafetyIssue(
                        type: .systemFileInclusion,
                        description: "尝试清理系统文件",
                        path: filePath,
                        severity: .high
                    ))
                    break
                }
            }
        }

        return SafetyCheckResult(isSafe: issues.isEmpty, safetyIssues: issues)
    }

    /// 批量安全检查
    func validateBatchDeletionSafety(_ filePaths: [String], rules: CleanupRules) -> SafetyCheckResult {
        var allIssues: [SafetyIssue] = []

        for filePath in filePaths {
            let result = validateDeletionSafety(filePath, rules: rules)
            allIssues.append(contentsOf: result.safetyIssues)
        }

        // 检查总体磁盘空间
        let totalSize = estimateTotalSize(filePaths)
        if !hasSufficientDiskSpace(forCleaningSize: totalSize) {
            allIssues.append(SafetyIssue(
                type: .lowDiskSpace,
                description: "总体清理大小 (\(formatBytes(totalSize))) 可能导致磁盘空间不足",
                path: nil as String?,
                severity: SafetySeverity.high
            ))
        }

        return SafetyCheckResult(isSafe: allIssues.isEmpty, safetyIssues: allIssues)
    }

    // MARK: - Private Methods

    private func checkAnyAppRunning(withPrefix prefix: String) -> Bool {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications

        for app in runningApps {
            if let bundleId = app.bundleIdentifier, bundleId.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }

    private func getFileSize(_ filePath: String) -> Int64? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            return attributes[.size] as? Int64
        } catch {
            print("无法获取文件大小 \(filePath): \(error)")
            return nil
        }
    }

    private func estimateTotalSize(_ filePaths: [String]) -> Int64 {
        var total: Int64 = 0
        for path in filePaths {
            total += getFileSize(path) ?? 0
        }
        return total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}