import XCTest
@testable import SpaceGuard

final class CleanupPresetManagerTests: XCTestCase {

    var presetManager: CleanupPresetManager!
    var mockUserDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // 使用临时UserDefaults避免污染实际数据
        mockUserDefaults = UserDefaults(suiteName: "TestSuite")
        mockUserDefaults?.removePersistentDomain(forName: "TestSuite")

        // 创建预设管理器，注入模拟的UserDefaults
        presetManager = CleanupPresetManager()
        // 注意：实际实现中CleanupPresetManager使用UserDefaults.standard
        // 在测试中我们无法直接注入，所以需要确保测试不会影响实际数据
        // 这里我们暂时依赖实际UserDefaults，但会在tearDown中清理
    }

    override func tearDown() {
        // 清理测试数据
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "customPresets")
        defaults.removeObject(forKey: "customPresetRules")
        defaults.synchronize()

        presetManager = nil
        super.tearDown()
    }

    func testManagerInitialization() {
        XCTAssertNotNil(presetManager)
    }

    func testGetPresetRules() {
        // 测试每个预设的规则生成
        let presets: [CleanupPreset] = [.safe, .developer, .advanced, .custom]

        for preset in presets {
            let rules = presetManager.getPresetRules(preset)
            XCTAssertNotNil(rules)

            // 验证基本规则属性存在
            switch preset {
            case .safe:
                XCTAssertTrue(rules.autoCleanLowRisk)
                XCTAssertTrue(rules.confirmMediumRisk)
                XCTAssertTrue(rules.neverDeleteHighRisk)
                XCTAssertEqual(rules.deleteDownloadsOlderThanDays, 180)
                XCTAssertEqual(rules.deleteLogsOlderThanDays, 60)
                XCTAssertEqual(rules.deleteCacheOlderThanDays, 30)
                XCTAssertEqual(rules.minimumFileSizeToConsider, 1024 * 1024) // 1MB
                XCTAssertEqual(rules.skipFilesLargerThan, 5 * 1024 * 1024 * 1024) // 5GB

            case .developer:
                XCTAssertTrue(rules.autoCleanLowRisk)
                XCTAssertFalse(rules.confirmMediumRisk)
                XCTAssertTrue(rules.neverDeleteHighRisk)
                XCTAssertEqual(rules.deleteDownloadsOlderThanDays, 90)
                XCTAssertEqual(rules.deleteLogsOlderThanDays, 14)
                XCTAssertEqual(rules.deleteCacheOlderThanDays, 7)
                XCTAssertEqual(rules.minimumFileSizeToConsider, 512 * 1024) // 512KB
                XCTAssertEqual(rules.skipFilesLargerThan, 2 * 1024 * 1024 * 1024) // 2GB
                // 验证开发者应用缓存包含
                XCTAssertTrue(rules.appCachesToClean.contains("com.microsoft.VSCode"))
                XCTAssertTrue(rules.appCachesToClean.contains("com.sublimetext.3"))

            case .advanced:
                XCTAssertTrue(rules.autoCleanLowRisk)
                XCTAssertTrue(rules.confirmMediumRisk)
                XCTAssertFalse(rules.neverDeleteHighRisk)
                XCTAssertEqual(rules.deleteDownloadsOlderThanDays, 30)
                XCTAssertEqual(rules.deleteLogsOlderThanDays, 7)
                XCTAssertEqual(rules.deleteCacheOlderThanDays, 3)
                XCTAssertEqual(rules.minimumFileSizeToConsider, 128 * 1024) // 128KB
                XCTAssertEqual(rules.skipFilesLargerThan, 10 * 1024 * 1024 * 1024) // 10GB
                // 验证包含系统位置
                XCTAssertTrue(rules.includeLocations.contains("/var/folders"))
                XCTAssertTrue(rules.includeLocations.contains("/private/var/folders"))

            case .custom:
                // 自定义预设的规则取决于保存的数据
                // 如果没有保存数据，应该是默认规则
                XCTAssertTrue(rules.autoCleanLowRisk) // 默认值 true
                XCTAssertTrue(rules.confirmMediumRisk) // 默认值 true
                XCTAssertTrue(rules.neverDeleteHighRisk) // 默认值 true
            }
        }
    }

    func testApplyPreset() {
        // 创建基础规则
        var baseRules = CleanupRules()
        baseRules.autoCleanLowRisk = false
        baseRules.confirmMediumRisk = false
        baseRules.neverDeleteHighRisk = false
        baseRules.deleteDownloadsOlderThanDays = 365
        baseRules.deleteLogsOlderThanDays = 180
        baseRules.deleteCacheOlderThanDays = 90
        baseRules.minimumFileSizeToConsider = 10 * 1024 * 1024 // 10MB
        baseRules.skipFilesLargerThan = 20 * 1024 * 1024 * 1024 // 20GB
        baseRules.includeLocations = ["/custom/path"]
        baseRules.appCachesToClean = ["com.test.app"]

        // 应用安全预设
        let updatedRules = presetManager.applyPreset(.safe, to: baseRules)

        // 验证预设设置覆盖了基础设置
        XCTAssertTrue(updatedRules.autoCleanLowRisk) // 预设值 true
        XCTAssertTrue(updatedRules.confirmMediumRisk) // 预设值 true
        XCTAssertTrue(updatedRules.neverDeleteHighRisk) // 预设值 true

        // 验证年龄阈值取较小值（更积极）
        XCTAssertEqual(updatedRules.deleteDownloadsOlderThanDays, 180) // 预设的180 < 基础365
        XCTAssertEqual(updatedRules.deleteLogsOlderThanDays, 60) // 预设的60 < 基础180
        XCTAssertEqual(updatedRules.deleteCacheOlderThanDays, 30) // 预设的30 < 基础90

        // 验证大小阈值取较小值
        XCTAssertEqual(updatedRules.minimumFileSizeToConsider, 1024 * 1024) // 预设的1MB < 基础10MB
        XCTAssertEqual(updatedRules.skipFilesLargerThan, 5 * 1024 * 1024 * 1024) // 预设的5GB < 基础20GB

        // 验证位置合并（去重）
        XCTAssertTrue(updatedRules.includeLocations.contains("/custom/path"))
        // 安全预设不添加额外位置，所以只有基础位置

        // 验证应用缓存合并
        XCTAssertTrue(updatedRules.appCachesToClean.contains("com.test.app"))

        // 验证预设已记录
        XCTAssertTrue(updatedRules.appliedPresets.contains(.safe))
    }

    func testSaveAndLoadCustomPresets() throws {
        // 创建自定义规则
        var customRules = CleanupRules()
        customRules.autoCleanLowRisk = true
        customRules.confirmMediumRisk = false
        customRules.neverDeleteHighRisk = true
        customRules.deleteDownloadsOlderThanDays = 60
        customRules.deleteLogsOlderThanDays = 30
        customRules.deleteCacheOlderThanDays = 14

        // 保存自定义预设
        try presetManager.saveCustomPreset(customRules, name: "测试预设")

        // 加载自定义预设
        let loadedPresets = presetManager.loadCustomPresets()

        // 验证加载成功
        XCTAssertEqual(loadedPresets.count, 1)

        let savedPreset = loadedPresets.first!
        XCTAssertEqual(savedPreset.name, "测试预设")
        XCTAssertEqual(savedPreset.rules.autoCleanLowRisk, true)
        XCTAssertEqual(savedPreset.rules.confirmMediumRisk, false)
        XCTAssertEqual(savedPreset.rules.neverDeleteHighRisk, true)
        XCTAssertEqual(savedPreset.rules.deleteDownloadsOlderThanDays, 60)
        XCTAssertEqual(savedPreset.rules.deleteLogsOlderThanDays, 30)
        XCTAssertEqual(savedPreset.rules.deleteCacheOlderThanDays, 14)
        XCTAssertNotNil(savedPreset.createdDate)
        XCTAssertNotNil(savedPreset.lastUsedDate)
    }

    func testDeleteCustomPreset() throws {
        // 先创建一个自定义预设
        var customRules = CleanupRules()
        customRules.autoCleanLowRisk = true

        try presetManager.saveCustomPreset(customRules, name: "待删除预设")

        var loadedPresets = presetManager.loadCustomPresets()
        XCTAssertEqual(loadedPresets.count, 1)

        let presetToDelete = loadedPresets.first!

        // 删除预设
        try presetManager.deleteCustomPreset(presetToDelete)

        // 验证删除成功
        loadedPresets = presetManager.loadCustomPresets()
        XCTAssertEqual(loadedPresets.count, 0)
    }

    func testGetPresetSavingsReport() {
        // 获取安全预设的报告
        let report = presetManager.getPresetSavingsReport(.safe)

        XCTAssertEqual(report.preset, .safe)
        XCTAssertGreaterThanOrEqual(report.totalSavings, 0)
        XCTAssertGreaterThanOrEqual(report.scenarioSavings, 0)
        XCTAssertGreaterThanOrEqual(report.ruleBasedSavings, 0)
        XCTAssertFalse(report.formattedTotalSavings.isEmpty)
        XCTAssertFalse(report.formattedScenarioSavings.isEmpty)
        XCTAssertNotNil(report.timestamp)

        // 验证百分比计算
        if report.totalSavings > 0 {
            let expectedPercentage = Double(report.scenarioSavings) / Double(report.totalSavings) * 100
            XCTAssertEqual(report.scenarioPercentage, expectedPercentage, accuracy: 0.01)
        }
    }

    func testCompareAllPresets() {
        let comparisons = presetManager.compareAllPresets()

        // 应该为每个预设生成一个比较结果
        XCTAssertEqual(comparisons.count, CleanupPreset.allCases.count)

        // 验证每个预设都有对应的比较结果
        let presetSet = Set(CleanupPreset.allCases)
        let comparisonPresetSet = Set(comparisons.map { $0.preset })
        XCTAssertEqual(presetSet, comparisonPresetSet)

        // 验证结果按节省空间降序排序
        for i in 0..<(comparisons.count - 1) {
            XCTAssertGreaterThanOrEqual(comparisons[i].savings, comparisons[i + 1].savings)
        }

        // 验证每个比较结果的属性
        for comparison in comparisons {
            XCTAssertNotNil(comparison.id)
            XCTAssertGreaterThanOrEqual(comparison.savings, 0)
            XCTAssertFalse(comparison.formattedSavings.isEmpty)
            XCTAssertGreaterThanOrEqual(comparison.scenarioCount, 0)

            // 验证风险等级
            switch comparison.preset {
            case .safe:
                XCTAssertEqual(comparison.riskLevel, .low)
            case .developer, .advanced, .custom:
                XCTAssertEqual(comparison.riskLevel, .medium)
            }

            // 验证推荐逻辑
            if comparison.preset == .safe {
                XCTAssertTrue(comparison.isRecommended)
            } else if comparison.preset == .developer {
                // 只有在节省空间大于100MB时才推荐
                XCTAssertEqual(comparison.isRecommended, comparison.savings > 100 * 1024 * 1024)
            } else {
                XCTAssertFalse(comparison.isRecommended)
            }
        }
    }

    func testPresetEnumProperties() {
        // 测试CleanupPreset枚举的属性
        let safePreset = CleanupPreset.safe

        XCTAssertEqual(safePreset.id, "safe")
        XCTAssertEqual(safePreset.displayName, "安全清理")
        XCTAssertEqual(safePreset.description, "仅清理低风险缓存和临时文件，适合大多数用户")
        XCTAssertEqual(safePreset.iconName, "shield.checkered")

        // 验证包含的场景
        let safeScenarios = safePreset.includedScenarios
        XCTAssertTrue(safeScenarios.contains(.wallpaperCache))
        XCTAssertTrue(safeScenarios.contains(.shipItCache))
        XCTAssertTrue(safeScenarios.contains(.homebrewCache))
        XCTAssertTrue(safeScenarios.contains(.npmCache))
        XCTAssertTrue(safeScenarios.contains(.pipCache))
        XCTAssertFalse(safeScenarios.contains(.trash))
        XCTAssertFalse(safeScenarios.contains(.jetbrainsCache))

        // 测试所有预设都有有效的属性
        for preset in CleanupPreset.allCases {
            XCTAssertFalse(preset.id.isEmpty)
            XCTAssertFalse(preset.displayName.isEmpty)
            XCTAssertFalse(preset.description.isEmpty)
            XCTAssertFalse(preset.iconName.isEmpty)
        }
    }

    func testPresetEstimatedSavings() {
        // 测试预估节省空间方法
        let estimator = SpaceEstimator()
        let safePreset = CleanupPreset.safe

        let savings1 = safePreset.estimatedSavings()
        let savings2 = safePreset.estimatedSavings(using: estimator)

        // 两个方法应返回相同结果（一个使用默认estimator，一个使用传入的）
        XCTAssertGreaterThanOrEqual(savings1, 0)
        XCTAssertGreaterThanOrEqual(savings2, 0)
        // 由于是估算，可能不完全相等，但应该是相同数量级

        // 测试格式化节省空间
        let formatted = safePreset.formattedSavings()
        XCTAssertFalse(formatted.isEmpty)
        // 验证包含数字（格式化字节数应包含数字）
        let containsDigit = formatted.rangeOfCharacter(from: .decimalDigits) != nil
        XCTAssertTrue(containsDigit, "格式化字符串应包含数字: \(formatted)")
    }
}