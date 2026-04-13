import Foundation

protocol SafetyChecking {
    func checkFileInUse(_ filePath: String) -> Bool
    func checkApplicationRunning(_ appBundleId: String) -> Bool
    func hasSufficientDiskSpace(forCleaningSize size: Int64, minimumFreeSpace: Int64) -> Bool
    func validateDeletionSafety(_ filePath: String, rules: CleanupRules?) -> SafetyCheckResult
    func validateBatchDeletionSafety(_ filePaths: [String], rules: CleanupRules) -> SafetyCheckResult
}

extension SafetyChecker: SafetyChecking {}
