import XCTest
@testable import SpaceGuard

final class CleanupPlannerTests: XCTestCase {
    private var planner: CleanupPlanner!

    override func setUp() {
        super.setUp()
        planner = CleanupPlanner(healthProvider: StorageHealthService())
    }

    override func tearDown() {
        planner = nil
        super.tearDown()
    }

    func testMakePlanBuildsRecommendedItemsAndProjectedFreeSpace() {
        let stats = DiskStats(total: 1_000, used: 900, free: 100)
        let rules = CleanupRules()
        let goal = StorageGoal(minimumFreeBytes: 180, minimumFreePercent: 0.10)
        let scenarios = [
            ScenarioDetectionResult(
                scenario: .trash,
                detected: true,
                estimatedSpace: 40,
                detectedPaths: ["/tmp/.Trash"],
                lastModified: nil
            ),
            ScenarioDetectionResult(
                scenario: .npmCache,
                detected: true,
                estimatedSpace: 60,
                detectedPaths: ["/Users/test/.npm"],
                lastModified: nil
            ),
            ScenarioDetectionResult(
                scenario: .wallpaperCache,
                detected: false,
                estimatedSpace: 500,
                detectedPaths: [],
                lastModified: nil
            )
        ]

        let plan = planner.makePlan(
            stats: stats,
            rules: rules,
            scenarioResults: scenarios,
            goal: goal
        )

        XCTAssertEqual(plan.items.count, 2)
        XCTAssertEqual(plan.items.first?.backingScenario, .trash)
        XCTAssertEqual(plan.totalEstimatedSavingsBytes, 100)
        XCTAssertEqual(plan.selectedEstimatedSavingsBytes, 100)
        XCTAssertEqual(plan.projectedFreeBytes, 200)
        XCTAssertEqual(plan.projectedGapToTargetBytes, 0)
        XCTAssertTrue(plan.reachesGoal)
    }

    func testMakePlanDoesNotDefaultSelectWhenLowRiskAutoCleanIsDisabled() {
        let stats = DiskStats(total: 1_000, used: 920, free: 80)
        var rules = CleanupRules()
        rules.autoCleanLowRisk = false
        let goal = StorageGoal(minimumFreeBytes: 160, minimumFreePercent: 0.10)
        let scenarios = [
            ScenarioDetectionResult(
                scenario: .shipItCache,
                detected: true,
                estimatedSpace: 50,
                detectedPaths: ["/Users/test/Library/Caches/app.ShipIt"],
                lastModified: nil
            )
        ]

        let plan = planner.makePlan(
            stats: stats,
            rules: rules,
            scenarioResults: scenarios,
            goal: goal
        )

        XCTAssertEqual(plan.items.count, 1)
        XCTAssertFalse(plan.items[0].defaultSelected)
        XCTAssertEqual(plan.selectedEstimatedSavingsBytes, 0)
        XCTAssertEqual(plan.projectedFreeBytes, 80)
        XCTAssertEqual(plan.projectedGapToTargetBytes, 80)
        XCTAssertFalse(plan.reachesGoal)
    }

    func testMakePlanUsesFileSelectionForDownloadInstallers() {
        let stats = DiskStats(total: 1_000, used: 900, free: 100)
        let rules = CleanupRules()
        let goal = StorageGoal(minimumFreeBytes: 180, minimumFreePercent: 0.10)
        let scenarios = [
            ScenarioDetectionResult(
                scenario: .downloadInstallers,
                detected: true,
                estimatedSpace: 75,
                detectedPaths: ["/Users/test/Downloads/old-installer.dmg"],
                lastModified: nil
            )
        ]

        let plan = planner.makePlan(
            stats: stats,
            rules: rules,
            scenarioResults: scenarios,
            goal: goal
        )

        XCTAssertEqual(plan.items.count, 1)
        XCTAssertEqual(plan.items[0].actionType, .fileSelection)
        XCTAssertFalse(plan.items[0].defaultSelected)
        XCTAssertEqual(plan.items[0].riskLevel, .medium)
    }
}
