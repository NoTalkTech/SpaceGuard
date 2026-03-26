import XCTest
@testable import SpaceGuard

final class CleanupScenariosDetectorTests: XCTestCase {

    var detector: CleanupScenariosDetector!

    override func setUp() {
        super.setUp()
        detector = CleanupScenariosDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    func testDetectorInitialization() {
        XCTAssertNotNil(detector)
    }

    func testAllScenariosEnum() {
        // 验证所有场景都包含在枚举中
        let allScenarios = CleanupScenario.allCases
        XCTAssertEqual(allScenarios.count, 8, "应该有8个清理场景")

        // 验证特定场景存在
        XCTAssertTrue(allScenarios.contains(.trash), "应包含废纸篓场景")
        XCTAssertTrue(allScenarios.contains(.wallpaperCache), "应包含壁纸缓存场景")
        XCTAssertTrue(allScenarios.contains(.jetbrainsCache), "应包含JetBrains缓存场景")
    }

    func testScenarioDetection() {
        // 注意：实际检测需要文件系统访问，这里我们测试接口
        let result = detector.detectScenario(.wallpaperCache)

        // 验证返回结果结构
        XCTAssertNotNil(result)
        XCTAssertEqual(result.scenario, .wallpaperCache)
        // detected属性可能为true或false，取决于实际文件系统状态
        XCTAssertEqual(result.detectedPaths.isEmpty, !result.detected, "detected属性应与detectedPaths一致")
    }

    func testDetectAllScenarios() {
        let results = detector.detectAllScenarios()

        XCTAssertEqual(results.count, CleanupScenario.allCases.count, "应为每个场景返回一个结果")

        // 验证每个结果都有正确的场景
        for (index, scenario) in CleanupScenario.allCases.enumerated() {
            XCTAssertEqual(results[index].scenario, scenario, "结果顺序应与场景枚举顺序匹配")
        }
    }

    func testFormatBytesFunction() {
        // 测试辅助函数
        let bytes: Int64 = 1024 * 1024 // 1 MB
        let formatted = formatBytes(bytes)

        XCTAssertNotNil(formatted)
        XCTAssertFalse(formatted.isEmpty, "格式化字符串不应为空")
        // 具体格式取决于地区设置，但至少应包含数字
        XCTAssertTrue(formatted.contains("1") || formatted.contains("MB"), "格式化字符串应表示1MB")
    }
}