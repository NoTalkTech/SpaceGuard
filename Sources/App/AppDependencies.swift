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
    let scenariosDetector: CleanupScenarioDetecting
    let storageHealthService: StorageHealthProviding
    let cleanupPlanner: CleanupPlanning
    let storageGoalPersistence: StorageGoalPersisting
    let cleanupExecutionCoordinator: CleanupExecutionCoordinating

    init() {
        let scanner = DiskScanner()
        let riskAnalyzer = RiskAnalyzer()
        let safetyChecker = SafetyChecker()
        let cleanupEngine = CleanupEngine()
        let historyManager = CleanupHistoryManager.shared
        let rulesPersistence = RulesPersistenceService()
        let scenariosDetector = CleanupScenariosDetector()
        let storageHealthService = StorageHealthService()
        let cleanupPlanner = CleanupPlanner(healthProvider: storageHealthService)
        let storageGoalPersistence = StorageGoalPersistenceService()
        let cleanupExecutionCoordinator = CleanupExecutionCoordinator(cleanupEngine: cleanupEngine)

        self.scanner = scanner
        self.riskAnalyzer = riskAnalyzer
        self.safetyChecker = safetyChecker
        self.cleanupEngine = cleanupEngine
        self.historyManager = historyManager
        self.rulesPersistence = rulesPersistence
        self.scenariosDetector = scenariosDetector
        self.storageHealthService = storageHealthService
        self.cleanupPlanner = cleanupPlanner
        self.storageGoalPersistence = storageGoalPersistence
        self.cleanupExecutionCoordinator = cleanupExecutionCoordinator
        self.progressTracker = ProgressTracker(
            scannerFactory: { DiskScanner() },
            engineFactory: { CleanupEngine() },
            historyManager: historyManager
        )
    }
}
