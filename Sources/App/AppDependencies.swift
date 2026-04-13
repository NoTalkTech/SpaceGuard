import Foundation

@MainActor
final class AppDependencies {
    let scanner: DiskScannerProtocol
    let riskAnalyzer: RiskAnalyzing
    let safetyChecker: SafetyChecking
    let cleanupEngine: CleanupEngine
    let historyManager: CleanupHistoryManager
    let rulesPersistence: RulesPersisting
    let progressTracker: ProgressTracker

    init() {
        let scanner = DiskScanner()
        let riskAnalyzer = RiskAnalyzer()
        let safetyChecker = SafetyChecker()
        let cleanupEngine = CleanupEngine()
        let historyManager = CleanupHistoryManager.shared
        let rulesPersistence = RulesPersistenceService()

        self.scanner = scanner
        self.riskAnalyzer = riskAnalyzer
        self.safetyChecker = safetyChecker
        self.cleanupEngine = cleanupEngine
        self.historyManager = historyManager
        self.rulesPersistence = rulesPersistence
        self.progressTracker = ProgressTracker(
            scannerFactory: { DiskScanner() },
            engineFactory: { CleanupEngine() },
            historyManager: historyManager
        )
    }
}
