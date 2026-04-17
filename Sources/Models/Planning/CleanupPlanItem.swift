import Foundation

enum CleanupPlanItemSource: String, Codable {
    case scenario
    case ruleDriven
    case insightOnly
}

enum RecoveryCost: String, Codable {
    case low
    case medium
    case high
}

enum Regenerability: String, Codable {
    case regenerable
    case partiallyRecoverable
    case nonRegenerable
}

enum CleanupActionType: String, Codable {
    case scenarioExecution
    case fileSelection
    case suggestOnly
}

struct CleanupPlanItem: Identifiable, Codable, Equatable {
    let id: UUID
    let source: CleanupPlanItemSource
    let title: String
    let summary: String
    let estimatedSavingsBytes: Int64
    let riskLevel: RiskLevel
    let recoveryCost: RecoveryCost
    let regenerability: Regenerability
    let recommended: Bool
    let defaultSelected: Bool
    let actionType: CleanupActionType
    let backingScenario: CleanupScenario?
    let backingPaths: [String]
    let recommendationReason: String
}
