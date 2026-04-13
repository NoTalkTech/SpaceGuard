import Foundation

protocol RulesPersisting {
    func loadRules() -> CleanupRules
    func saveRules(_ rules: CleanupRules)
}
