import Foundation

protocol CleanupEngineProtocol {
    func cleanupFiles(
        _ files: [FileItem],
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)?
    ) async -> CleanupEngine.CleanupResult

    func quickCleanup(
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)?
    ) async -> CleanupEngine.CleanupResult

    func performBatchCleanup(
        selections: [FileSelection],
        progress: @escaping (Int, Int, Int64) -> Void
    ) async -> CleanupEngine.CleanupResult

    func executeScenarioCleanup(
        _ scenario: CleanupScenario,
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void
    ) async -> CleanupEngine.CleanupResult

    func cancelCleanup()
    func getQuickCleanupPaths() -> [String]
}

extension CleanupEngine: CleanupEngineProtocol {}
