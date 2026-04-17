import Foundation

struct CleanupPlan: Codable, Equatable {
    let createdAt: Date
    let health: StorageHealthSnapshot
    let items: [CleanupPlanItem]
    let totalEstimatedSavingsBytes: Int64
    let selectedEstimatedSavingsBytes: Int64
    let projectedFreeBytes: Int64
    let projectedGapToTargetBytes: Int64
    let reachesGoal: Bool
}

struct CleanupExecutionPlan: Equatable {
    let selectedItems: [CleanupPlanItem]
}
