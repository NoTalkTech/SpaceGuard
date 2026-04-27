import Foundation

protocol CleanupPlanning {
    func makePlan(
        stats: DiskStats,
        rules: CleanupRules,
        scenarioResults: [ScenarioDetectionResult],
        goal: StorageGoal
    ) -> CleanupPlan
}
