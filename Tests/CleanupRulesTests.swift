import XCTest
@testable import SpaceGuard

final class CleanupRulesTests: XCTestCase {

    func testDefaultInitialization() {
        let rules = CleanupRules()

        // 验证默认值
        XCTAssertTrue(rules.autoCleanLowRisk)
        XCTAssertTrue(rules.confirmMediumRisk)
        XCTAssertTrue(rules.neverDeleteHighRisk)

        XCTAssertEqual(rules.deleteDownloadsOlderThanDays, 90)
        XCTAssertEqual(rules.deleteLogsOlderThanDays, 30)
        XCTAssertEqual(rules.deleteCacheOlderThanDays, 7)

        XCTAssertEqual(rules.minimumFileSizeToConsider, 1024 * 1024) // 1MB
        XCTAssertEqual(rules.skipFilesLargerThan, 1024 * 1024 * 1024) // 1GB

        // 验证默认包含位置
        XCTAssertTrue(rules.includeLocations.contains(NSHomeDirectory() + "/Library/Caches"))
        XCTAssertTrue(rules.includeLocations.contains(NSHomeDirectory() + "/Downloads"))
        XCTAssertTrue(rules.includeLocations.contains("/Library/Caches"))
        XCTAssertTrue(rules.includeLocations.contains("/var/tmp"))
        XCTAssertTrue(rules.includeLocations.contains("/tmp"))

        // 验证默认排除位置
        XCTAssertTrue(rules.excludeLocations.contains(NSHomeDirectory() + "/Documents"))
        XCTAssertTrue(rules.excludeLocations.contains(NSHomeDirectory() + "/Desktop"))
        XCTAssertTrue(rules.excludeLocations.contains("/System"))
        XCTAssertTrue(rules.excludeLocations.contains("/usr"))

        // 验证应用缓存列表
        XCTAssertTrue(rules.appCachesToClean.contains("com.apple.Safari"))
        XCTAssertTrue(rules.appCachesToClean.contains("com.google.Chrome"))
        XCTAssertTrue(rules.appCachesToClean.contains("com.microsoft.VSCode"))

        // 验证高级规则
        XCTAssertNotNil(rules.fileTypeRules)
        XCTAssertNotNil(rules.customRiskOverrides)
        XCTAssertNotNil(rules.exclusionPatterns)
        XCTAssertNil(rules.scheduledCleanup)

    }

    func testDetectConflicts() {
        var rules = CleanupRules()
        let ruleManager = RuleManager()

        // 测试1：路径包含/排除冲突
        rules.includeLocations = ["/Users/test/Documents"]
        rules.excludeLocations = ["/Users/test/Documents/Subfolder"]

        let conflicts1 = ruleManager.detectConflicts(rules)
        XCTAssertEqual(conflicts1.count, 1)
        if let conflict = conflicts1.first {
            XCTAssertEqual(conflict.type, .pathInclusionExclusion)
            XCTAssertTrue(conflict.description.contains("Path '/Users/test/Documents' is both included and excluded"))
            XCTAssertEqual(conflict.severity, .high)
        }

        // 测试2：文件类型规则冲突
        rules.fileTypeRules.whitelistedExtensions = [".txt", ".pdf"]
        rules.fileTypeRules.blacklistedExtensions = [".txt", ".doc"]

        let conflicts2 = ruleManager.detectConflicts(rules)
        XCTAssertEqual(conflicts2.count, 2) // 1个路径冲突 + 1个文件类型冲突
        let fileTypeConflict = conflicts2.first { $0.type == .fileTypeRule }
        XCTAssertNotNil(fileTypeConflict)
        if let conflict = fileTypeConflict {
            XCTAssertTrue(conflict.description.contains("File extension '.txt' is both whitelisted and blacklisted"))
            XCTAssertEqual(conflict.severity, .medium)
        }

        // 测试3：自定义风险覆盖与系统路径冲突
        let customOverride = CustomRiskOverride(path: "/System/Library", riskLevel: .low)
        rules.customRiskOverrides = [customOverride]

        let conflicts3 = ruleManager.detectConflicts(rules)
        let customOverrideConflict = conflicts3.first { $0.type == .customRiskOverride }
        XCTAssertNotNil(customOverrideConflict)
        if let conflict = customOverrideConflict {
            XCTAssertTrue(conflict.description.contains("Custom risk override for system path '/System/Library'"))
            XCTAssertTrue(conflict.description.contains("system files should typically be high risk"))
            XCTAssertEqual(conflict.severity, .high)
        }

        // 测试4：年龄阈值冲突
        rules.deleteDownloadsOlderThanDays = 0
        rules.deleteCacheOlderThanDays = -1

        let conflicts4 = ruleManager.detectConflicts(rules)
        let ageConflicts = conflicts4.filter { $0.type == .ageThreshold }
        XCTAssertEqual(ageConflicts.count, 2)

        let downloadConflict = ageConflicts.first { $0.description.contains("Download age threshold") }
        XCTAssertNotNil(downloadConflict)
        if let conflict = downloadConflict {
            XCTAssertTrue(conflict.description.contains("0 days"))
            XCTAssertEqual(conflict.severity, .medium)
        }

        let cacheConflict = ageConflicts.first { $0.description.contains("Cache age threshold") }
        XCTAssertNotNil(cacheConflict)
        if let conflict = cacheConflict {
            XCTAssertTrue(conflict.description.contains("-1 days"))
            XCTAssertEqual(conflict.severity, .high)
        }
    }

    func testResolveConflicts() {
        var rules = CleanupRules()
        let ruleManager = RuleManager()

        // 设置冲突
        rules.fileTypeRules.whitelistedExtensions = [".txt", ".pdf", ".doc"]
        rules.fileTypeRules.blacklistedExtensions = [".txt", ".exe"]

        rules.customRiskOverrides = [
            CustomRiskOverride(path: "/System/Library", riskLevel: .low),
            CustomRiskOverride(path: "/usr/bin", riskLevel: .medium)
        ]

        rules.deleteDownloadsOlderThanDays = 0
        rules.deleteLogsOlderThanDays = -5
        rules.deleteCacheOlderThanDays = -10

        // 解决冲突
        ruleManager.resolveConflicts(&rules)

        // 验证文件类型冲突已解决：黑名单优先
        XCTAssertFalse(rules.fileTypeRules.whitelistedExtensions.contains(".txt"))
        XCTAssertTrue(rules.fileTypeRules.whitelistedExtensions.contains(".pdf"))
        XCTAssertTrue(rules.fileTypeRules.whitelistedExtensions.contains(".doc"))
        XCTAssertTrue(rules.fileTypeRules.blacklistedExtensions.contains(".txt"))
        XCTAssertTrue(rules.fileTypeRules.blacklistedExtensions.contains(".exe"))

        // 验证系统文件风险级别已修复为高风险
        for override in rules.customRiskOverrides {
            if override.path.hasPrefix("/System") || override.path.hasPrefix("/usr") {
                XCTAssertEqual(override.riskLevel, .high)
            }
        }

        // 验证年龄阈值已修复
        XCTAssertEqual(rules.deleteDownloadsOlderThanDays, 1) // 最小为1
        XCTAssertEqual(rules.deleteLogsOlderThanDays, 0) // 最小为0
        XCTAssertEqual(rules.deleteCacheOlderThanDays, 0) // 最小为0
    }

    func testSaveAndLoad() {
        // 创建自定义规则
        var originalRules = CleanupRules()
        originalRules.autoCleanLowRisk = false
        originalRules.confirmMediumRisk = false
        originalRules.neverDeleteHighRisk = false
        originalRules.deleteDownloadsOlderThanDays = 30
        originalRules.deleteLogsOlderThanDays = 7
        originalRules.deleteCacheOlderThanDays = 3
        originalRules.minimumFileSizeToConsider = 512 * 1024
        originalRules.skipFilesLargerThan = 2 * 1024 * 1024 * 1024

        originalRules.includeLocations = ["/custom/include"]
        originalRules.excludeLocations = ["/custom/exclude"]
        originalRules.appCachesToClean = ["com.test.app"]

        originalRules.fileTypeRules = FileTypeRules(
            whitelistedExtensions: [".txt", ".md"],
            blacklistedExtensions: [".exe", ".dmg"]
        )

        originalRules.customRiskOverrides = [
            CustomRiskOverride(path: "/custom/path", riskLevel: .medium)
        ]

        originalRules.exclusionPatterns = ["*.tmp", "*.log"]

        // 保存规则
        RulesPersistenceService().saveRules(originalRules)

        // 加载规则
        let loadedRules = RulesPersistenceService().loadRules()

        // 验证基本属性
        XCTAssertEqual(loadedRules.autoCleanLowRisk, originalRules.autoCleanLowRisk)
        XCTAssertEqual(loadedRules.confirmMediumRisk, originalRules.confirmMediumRisk)
        XCTAssertEqual(loadedRules.neverDeleteHighRisk, originalRules.neverDeleteHighRisk)
        XCTAssertEqual(loadedRules.deleteDownloadsOlderThanDays, originalRules.deleteDownloadsOlderThanDays)
        XCTAssertEqual(loadedRules.deleteLogsOlderThanDays, originalRules.deleteLogsOlderThanDays)
        XCTAssertEqual(loadedRules.deleteCacheOlderThanDays, originalRules.deleteCacheOlderThanDays)
        XCTAssertEqual(loadedRules.minimumFileSizeToConsider, originalRules.minimumFileSizeToConsider)
        XCTAssertEqual(loadedRules.skipFilesLargerThan, originalRules.skipFilesLargerThan)

        // 验证位置
        XCTAssertEqual(loadedRules.includeLocations.sorted(), originalRules.includeLocations.sorted())
        XCTAssertEqual(loadedRules.excludeLocations.sorted(), originalRules.excludeLocations.sorted())
        XCTAssertEqual(loadedRules.appCachesToClean.sorted(), originalRules.appCachesToClean.sorted())

        // 验证文件类型规则
        XCTAssertEqual(loadedRules.fileTypeRules.whitelistedExtensions.sorted(), originalRules.fileTypeRules.whitelistedExtensions.sorted())
        XCTAssertEqual(loadedRules.fileTypeRules.blacklistedExtensions.sorted(), originalRules.fileTypeRules.blacklistedExtensions.sorted())

        // 验证自定义风险覆盖
        XCTAssertEqual(loadedRules.customRiskOverrides.count, originalRules.customRiskOverrides.count)
        if loadedRules.customRiskOverrides.count == originalRules.customRiskOverrides.count {
            for i in 0..<loadedRules.customRiskOverrides.count {
                XCTAssertEqual(loadedRules.customRiskOverrides[i].path, originalRules.customRiskOverrides[i].path)
                XCTAssertEqual(loadedRules.customRiskOverrides[i].riskLevel, originalRules.customRiskOverrides[i].riskLevel)
            }
        }

        // 验证排除模式
        XCTAssertEqual(loadedRules.exclusionPatterns.sorted(), originalRules.exclusionPatterns.sorted())

    }


    func testShouldIncludeFileMethod() {
        let rules = CleanupRules()

        // 测试包含位置
        let includePath = NSHomeDirectory() + "/Library/Caches/testfile.txt"
        XCTAssertTrue(rules.shouldIncludeFile(at: includePath))

        // 测试排除位置
        let excludePath = NSHomeDirectory() + "/Documents/testfile.txt"
        XCTAssertFalse(rules.shouldIncludeFile(at: excludePath))

        // 测试不在任何列表中的路径
        let unknownPath = "/some/random/path/file.txt"
        XCTAssertFalse(rules.shouldIncludeFile(at: unknownPath)) // 默认不包含未知路径
    }

    func testRuleConflictSeverity() {
        // 测试冲突结构
        let conflict = RuleConflict(
            type: .pathInclusionExclusion,
            description: "Test conflict",
            severity: .high
        )

        XCTAssertEqual(conflict.type, .pathInclusionExclusion)
        XCTAssertEqual(conflict.description, "Test conflict")
        XCTAssertEqual(conflict.severity, .high)
        XCTAssertNotNil(conflict.id)

        // 测试所有冲突类型都可以创建冲突
        let conflictTypes: [RuleConflictType] = [.pathInclusionExclusion, .fileTypeRule, .customRiskOverride, .ageThreshold]
        for conflictType in conflictTypes {
            let testConflict = RuleConflict(
                type: conflictType,
                description: "Test \(conflictType)",
                severity: .medium
            )
            XCTAssertEqual(testConflict.type, conflictType)
            XCTAssertFalse(testConflict.description.isEmpty)
            XCTAssertNotNil(testConflict.id)
        }
    }
}
