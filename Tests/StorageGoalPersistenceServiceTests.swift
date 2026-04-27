import XCTest
@testable import SpaceGuard

final class StorageGoalPersistenceServiceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var service: StorageGoalPersistenceService!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "StorageGoalPersistenceServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        service = StorageGoalPersistenceService(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        service = nil
        suiteName = nil
        super.tearDown()
    }

    func testLoadGoalReturnsDefaultsWhenNothingSaved() {
        let goal = service.loadGoal()

        XCTAssertEqual(goal, StorageGoal())
    }

    func testSaveGoalPersistsValues() {
        let goal = StorageGoal(
            minimumFreeBytes: 120 * 1024 * 1024 * 1024,
            minimumFreePercent: 0.25
        )

        service.saveGoal(goal)

        let loaded = service.loadGoal()
        XCTAssertEqual(loaded, goal)
    }
}
