import XCTest
@testable import SpaceGuard

final class SpaceEstimatorTests: XCTestCase {

    var estimator: SpaceEstimator!
    private let mockDetector = MockCleanupScenariosDetector()

    override func setUp() {
        super.setUp()
        estimator = SpaceEstimator(detector: mockDetector)
    }

    override func tearDown() {
        estimator = nil
        super.tearDown()
    }

    func testEstimatorInitialization() {
        XCTAssertNotNil(estimator)
    }

    func testEstimateSpaceForScenario() {
        // 测试单个场景的空间预估
        let scenario = CleanupScenario.trash
        let estimatedSpace = estimator.estimateSpace(for: scenario)

        // 验证返回的是有效值（可能为0或正数）
        XCTAssertGreaterThanOrEqual(estimatedSpace, 0, "预估空间应为非负数")
    }

    func testEstimateSpaceForMultipleScenarios() {
        // 测试多个场景的空间预估
        let scenarios: [CleanupScenario] = [.trash, .wallpaperCache]
        let estimatedSpace = estimator.estimateSpace(for: scenarios)

        XCTAssertGreaterThanOrEqual(estimatedSpace, 0, "预估空间应为非负数")
    }

    func testEstimateTotalSavings() {
        // 测试总节省空间预估
        let totalSavings = estimator.estimateTotalSavings()

        // 验证返回的是有效值（可能为0或正数）
        XCTAssertGreaterThanOrEqual(totalSavings, 0, "总节省空间应为非负数")
    }

    func testGenerateReport() {
        // 测试报告生成
        let report = estimator.generateReport()

        XCTAssertNotNil(report)
        XCTAssertGreaterThanOrEqual(report.totalSavings, 0, "报告中的总节省空间应为非负数")
        XCTAssertGreaterThanOrEqual(report.scenarioCount, 0, "检测到的场景数应为非负数")
        XCTAssertLessThanOrEqual(report.scenarioCount, CleanupScenario.allCases.count, "检测到的场景数不应超过总场景数")
    }

    func testFormatBytesMethod() {
        // 测试SpaceEstimator内部的formatBytes方法
        let bytes: Int64 = 1024 * 1024 * 5 // 5 MB
        let formatted = estimator.formatBytes(bytes)

        XCTAssertNotNil(formatted)
        XCTAssertFalse(formatted.isEmpty, "格式化字符串不应为空")
        // 验证包含数字
        let containsDigit = formatted.rangeOfCharacter(from: .decimalDigits) != nil
        XCTAssertTrue(containsDigit, "格式化字符串应包含数字")
    }
}

private struct MockCleanupScenariosDetector: CleanupScenarioDetecting {
    func detectAllScenarios() -> [ScenarioDetectionResult] {
        [
            ScenarioDetectionResult(
                scenario: .trash,
                detected: true,
                estimatedSpace: 50 * 1024 * 1024,
                detectedPaths: ["/tmp/.Trash"],
                lastModified: Date()
            ),
            ScenarioDetectionResult(
                scenario: .wallpaperCache,
                detected: true,
                estimatedSpace: 300 * 1024 * 1024,
                detectedPaths: ["/tmp/wallpaper"],
                lastModified: Date()
            ),
            ScenarioDetectionResult(
                scenario: .npmCache,
                detected: false,
                estimatedSpace: 0,
                detectedPaths: [],
                lastModified: nil
            )
        ]
    }

    func estimateSpaceForScenario(_ scenario: CleanupScenario) -> Int64 {
        detectAllScenarios().first(where: { $0.scenario == scenario })?.estimatedSpace ?? 0
    }
}
