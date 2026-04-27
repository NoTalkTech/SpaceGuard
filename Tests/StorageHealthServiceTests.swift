import XCTest
@testable import SpaceGuard

final class StorageHealthServiceTests: XCTestCase {
    private var service: StorageHealthService!

    override func setUp() {
        super.setUp()
        service = StorageHealthService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    func testMakeSnapshotIsSafeWhenFreeSpaceAlreadyMeetsGoal() {
        let stats = DiskStats(
            total: 1_000,
            used: 700,
            free: 300
        )
        let goal = StorageGoal(minimumFreeBytes: 200, minimumFreePercent: 0.10)

        let snapshot = service.makeSnapshot(stats: stats, goal: goal)

        XCTAssertEqual(snapshot.targetFreeBytes, 200)
        XCTAssertEqual(snapshot.gapToTargetBytes, 0)
        XCTAssertEqual(snapshot.level, .safe)
    }

    func testMakeSnapshotIsWarningWhenGapExistsButFreeSpaceStillAboveHalfTarget() {
        let stats = DiskStats(
            total: 1_000,
            used: 880,
            free: 120
        )
        let goal = StorageGoal(minimumFreeBytes: 200, minimumFreePercent: 0.10)

        let snapshot = service.makeSnapshot(stats: stats, goal: goal)

        XCTAssertEqual(snapshot.targetFreeBytes, 200)
        XCTAssertEqual(snapshot.gapToTargetBytes, 80)
        XCTAssertEqual(snapshot.level, .warning)
    }

    func testMakeSnapshotIsUrgentWhenFreeSpaceFallsBelowHalfTarget() {
        let stats = DiskStats(
            total: 1_000,
            used: 930,
            free: 70
        )
        let goal = StorageGoal(minimumFreeBytes: 200, minimumFreePercent: 0.10)

        let snapshot = service.makeSnapshot(stats: stats, goal: goal)

        XCTAssertEqual(snapshot.targetFreeBytes, 200)
        XCTAssertEqual(snapshot.gapToTargetBytes, 130)
        XCTAssertEqual(snapshot.level, .urgent)
    }
}
