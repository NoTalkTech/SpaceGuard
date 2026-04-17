import Foundation

struct CleanupExecutionUpdate {
    let currentItemTitle: String
    let currentItemIndex: Int
    let totalItems: Int
    let overallProgress: Double
    let totalSpaceFreed: Int64
}

struct CleanupExecutionSummary {
    let executedItems: [CleanupPlanItem]
    let filesDeleted: Int
    let spaceFreed: Int64
    let duration: TimeInterval
    let errors: [CleanupEngine.CleanupError]
}

protocol CleanupExecutionCoordinating {
    func execute(
        items: [CleanupPlanItem],
        rules: CleanupRules,
        update: @escaping (CleanupExecutionUpdate) -> Void
    ) async -> CleanupExecutionSummary
}
