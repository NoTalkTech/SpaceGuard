import Foundation

class CleanupEngine {
    let ruleManager = RuleManager()
    private let decider: DeletionDecider
    private let deleter = FileDeleter()
    private let riskAnalyzer = RiskAnalyzer()
    private let safetyChecker = SafetyChecker()
    private var isCleaning = false
    private var cancellationToken: Bool = false

    init() {
        self.decider = DeletionDecider(ruleManager: ruleManager)
    }

    struct CleanupResult {
        let filesDeleted: Int
        let spaceFreed: Int64
        let duration: TimeInterval
        let errors: [CleanupError]
    }

    struct CleanupError: Error {
        let filePath: String
        let error: Swift.Error
    }

    func cleanupFiles(
        _ files: [FileItem],
        rules: CleanupRules,
        progress: @escaping (Int, Int, Int64) -> Void,
        confirmAction: ((FileItem) async -> Bool)? = nil
    ) async -> CleanupResult {
        guard !isCleaning else {
            return CleanupResult(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: [])
        }

        // Step 1: Validate and resolve rule conflicts
        var validatedRules = rules
        ruleManager.applyRulePriorityManagement(&validatedRules)

        // Optional: Log any remaining conflicts for user awareness
        let (_, conflicts) = ruleManager.validateRules(validatedRules)
        if !conflicts.isEmpty {
            print("Warning: Found \(conflicts.count) rule conflicts after resolution:")
            for conflict in conflicts {
                print("  - \(conflict.description) (\(conflict.severity.rawValue))")
            }
        }

        isCleaning = true
        cancellationToken = false
        let startTime = Date()

        defer {
            isCleaning = false
            cancellationToken = false
        }

        var filesDeleted = 0
        var spaceFreed: Int64 = 0
        var errors: [CleanupError] = []

        let totalFiles = files.count

        for (index, file) in files.enumerated() {
            if cancellationToken {
                break
            }

            // Check rules and get deletion decision with risk assessment
            // Apply dynamic rules based on file characteristics
            let dynamicRules = ruleManager.applyDynamicRules(file, validatedRules)
            let (deletionDecision, _) = decider.shouldDeleteFileWithAssessment(file, rules: dynamicRules)

            switch deletionDecision {
            case .skip:
                continue
            case .confirm:
                // Ask for confirmation if callback provided
                if let confirmAction = confirmAction {
                    let shouldDelete = await confirmAction(file)
                    if !shouldDelete {
                        continue
                    }
                } else {
                    // No confirmation callback, skip the file
                    continue
                }
            case .delete:
                break // Proceed with deletion
            }

            do {
                try deleter.deleteFile(file)
                filesDeleted += 1
                spaceFreed += file.size

                // Update progress
                progress(index + 1, totalFiles, spaceFreed)

                // Small delay to avoid overwhelming the system
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            } catch {
                errors.append(CleanupError(filePath: file.path, error: error))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return CleanupResult(
            filesDeleted: filesDeleted,
            spaceFreed: spaceFreed,
            duration: duration,
            errors: errors
        )
    }

    func cancelCleanup() {
        cancellationToken = true
    }

    func calculatePotentialSavings(_ files: [FileItem], rules: CleanupRules) -> (lowRisk: Int64, mediumRisk: Int64, highRisk: Int64) {
        var lowRiskSavings: Int64 = 0
        var mediumRiskSavings: Int64 = 0
        var highRiskSavings: Int64 = 0

        for file in files {
            if !rules.shouldIncludeFile(at: file.path) {
                continue
            }

            switch file.riskLevel {
            case .low:
                if rules.autoCleanLowRisk {
                    lowRiskSavings += file.size
                }
            case .medium:
                if rules.confirmMediumRisk {
                    mediumRiskSavings += file.size
                }
            case .high:
                if !rules.neverDeleteHighRisk {
                    highRiskSavings += file.size
                }
            }
        }

        return (lowRiskSavings, mediumRiskSavings, highRiskSavings)
    }

    /// Get the list of paths used for quick cleanup
    ///
    /// This method returns a curated list of cache and temporary directories that are
    /// typically safe to clean during a quick cleanup operation. The paths are selected
    /// based on the following principles:
    /// 1. **User cache directories** (`~/Library/Caches`) - Application-specific caches
    ///    that can be regenerated and typically contain low-risk files
    /// 2. **System cache directories** (`/Library/Caches`) - Shared system caches
    ///    used by multiple applications
    /// 3. **Log directories** (`~/Library/Logs`) - Application logs that are often
    ///    safe to remove but may affect debugging
    /// 4. **Temporary directories** (`/tmp`, `/var/tmp`) - System-wide temporary files
    ///    that are often safe to delete
    ///
    /// The paths are ordered with user-specific directories first, as they are
    /// generally safer to clean. System directories are included because they often
    /// accumulate large amounts of temporary data but require careful risk assessment.
    func getQuickCleanupPaths() -> [String] {
        return [
            NSHomeDirectory() + "/Library/Caches",
            "/Library/Caches",
            NSHomeDirectory() + "/Library/Logs",
            "/var/tmp",
            "/tmp"
        ]
    }

    func quickCleanup(rules: CleanupRules, progress: @escaping (Int, Int, Int64) -> Void, confirmAction: ((FileItem) async -> Bool)? = nil) async -> CleanupResult {
        // Apply rule validation and priority management before processing
        var validatedRules = rules
        ruleManager.applyRulePriorityManagement(&validatedRules)

        // Identify common cache locations
        let cachePaths = getQuickCleanupPaths()

        var allFiles: [FileItem] = []
        var scanErrors: [CleanupError] = []
        let fm = FileManager.default

        for path in cachePaths {
            guard fm.fileExists(atPath: path) else {
                continue
            }

            do {
                let scanner = DiskScanner()
                let result = try await scanner.scanDirectory(at: path) { _, _ in }
                let analyzedFiles = riskAnalyzer.analyzeFiles(result.files, rules: validatedRules)
                allFiles.append(contentsOf: analyzedFiles)
            } catch {
                print("Error scanning \(path): \(error)")
                scanErrors.append(CleanupError(filePath: path, error: error))
            }
        }

        // Filter for low-risk files only
        let lowRiskFiles = allFiles.filter { $0.riskLevel == .low }

        let cleanupResult = await cleanupFiles(lowRiskFiles, rules: validatedRules, progress: progress, confirmAction: confirmAction)

        // Combine scan errors with cleanup errors
        let combinedErrors = scanErrors + cleanupResult.errors

        return CleanupResult(
            filesDeleted: cleanupResult.filesDeleted,
            spaceFreed: cleanupResult.spaceFreed,
            duration: cleanupResult.duration,
            errors: combinedErrors
        )
    }

    // MARK: - Scenario-Based Cleanup Methods

    /// Perform safe cleanup process with safety checks and space estimation
    func performSafeCleanup(rules: CleanupRules, progress: @escaping (Int, Int, Int64) -> Void) async -> CleanupResult {
        // Step 1: Validate cleanup safety
        let safetyResult = validateCleanupSafety(rules: rules)
        guard safetyResult.isSafe else {
            var errors: [CleanupError] = []
            for issue in safetyResult.safetyIssues {
                errors.append(CleanupError(filePath: issue.path ?? "general", error: NSError(domain: "SafetyCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: issue.description])))
            }
            return CleanupResult(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: errors)
        }

        // Step 2: Estimate cleanup space
        let estimatedSpace = estimateCleanupSpace(rules: rules)
        print("Estimated cleanup space: \(deleter.formatBytes(estimatedSpace))")

        // Step 3: Scan for files using rules
        var allFiles: [FileItem] = []
        let fm = FileManager.default

        for includePath in (rules.includeLocations.isEmpty ? [NSHomeDirectory()] : rules.includeLocations) {
            guard fm.fileExists(atPath: includePath) else { continue }

            do {
                let scanner = DiskScanner()
                let scanResult = try await scanner.scanDirectory(at: includePath) { scanned, total in
                    progress(0, 1, 0) // Update progress during scan
                }
                let analyzedFiles = riskAnalyzer.analyzeFiles(scanResult.files, rules: rules)
                allFiles.append(contentsOf: analyzedFiles)
            } catch {
                // Continue with other paths
                continue
            }
        }

        // Step 4: Filter low and medium risk files (safe cleanup)
        let safeFiles = allFiles.filter { file in
            if file.riskLevel == .low && rules.autoCleanLowRisk {
                return true
            }
            if file.riskLevel == .medium && rules.confirmMediumRisk {
                return true
            }
            return false
        }

        // Step 5: Execute cleanup
        return await cleanupFiles(safeFiles, rules: rules, progress: progress, confirmAction: nil)
    }

    /// Perform batch cleanup with confirmed file selections
    func performBatchCleanup(
        selections: [FileSelection],
        progress: @escaping (Int, Int, Int64) -> Void
    ) async -> CleanupResult {
        guard !isCleaning else {
            return CleanupResult(filesDeleted: 0, spaceFreed: 0, duration: 0, errors: [])
        }

        isCleaning = true
        cancellationToken = false
        let startTime = Date()

        defer {
            isCleaning = false
            cancellationToken = false
        }

        var filesDeleted = 0
        var spaceFreed: Int64 = 0
        var errors: [CleanupError] = []

        let totalFiles = selections.count

        for (index, selection) in selections.enumerated() {
            if cancellationToken {
                break
            }

            guard selection.shouldDelete else { continue }

            do {
                try deleter.deleteFile(selection.file)
                filesDeleted += 1
                spaceFreed += selection.file.size

                // Update progress
                progress(index + 1, totalFiles, spaceFreed)

                // Small delay to avoid overwhelming system
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            } catch {
                errors.append(CleanupError(filePath: selection.file.path, error: error))
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        return CleanupResult(
            filesDeleted: filesDeleted,
            spaceFreed: spaceFreed,
            duration: duration,
            errors: errors
        )
    }

    /// Validate cleanup safety by checking various conditions
    func validateCleanupSafety(rules: CleanupRules) -> SafetyCheckResult {
        var issues: [SafetyIssue] = []

        // Check if any included paths contain system files
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library"]
        for includePath in rules.includeLocations {
            for systemPath in systemPaths {
                if includePath.hasPrefix(systemPath) {
                    issues.append(SafetyIssue(
                        type: .systemFileInclusion,
                        description: "Included path contains system files: \(includePath)",
                        path: includePath,
                        severity: .high
                    ))
                    break
                }
            }
        }

        // Check if applications associated with included paths are running
        for includePath in rules.includeLocations {
            if safetyChecker.checkApplicationForPathRunning(includePath) {
                issues.append(SafetyIssue(
                    type: .applicationRunning,
                    description: "Application associated with path is running: \(includePath)",
                    path: includePath,
                    severity: .medium
                ))
            }
        }

        // Check disk space for estimated cleanup size
        let estimatedSize = estimateCleanupSpace(rules: rules)
        if !safetyChecker.hasSufficientDiskSpace(forCleaningSize: estimatedSize) {
            issues.append(SafetyIssue(
                type: .lowDiskSpace,
                description: "Insufficient disk space for estimated cleanup size (\(deleter.formatBytes(estimatedSize)))",
                path: nil,
                severity: .high
            ))
        }

        return SafetyCheckResult(isSafe: issues.isEmpty, safetyIssues: issues)
    }

    /// Estimate cleanup space based on rules and scenarios
    func estimateCleanupSpace(rules: CleanupRules) -> Int64 {
        let estimator = SpaceEstimator()
        return estimator.estimateSpaceForRules(rules)
    }

    /// Execute cleanup for a specific scenario
    func executeScenarioCleanup(_ scenario: CleanupScenario, rules: CleanupRules, progress: @escaping (Int, Int, Int64) -> Void) async -> CleanupResult {
        let detector = CleanupScenariosDetector()
        let result = detector.detectScenario(scenario)

        guard result.detected else {
            return CleanupResult(
                filesDeleted: 0,
                spaceFreed: 0,
                duration: 0,
                errors: [CleanupError(filePath: scenario.displayName, error: NSError(domain: "ScenarioCleanup", code: 404, userInfo: [NSLocalizedDescriptionKey: "Scenario not detected: \(scenario.displayName)"]))]
            )
        }

        // For scenarios that use command line cleanup
        if scenario.usesCommandLine, let command = scenario.cleanupCommand {
            do {
                let output = try deleter.executeCommand(command)
                // Log command output for debugging
                if !output.isEmpty {
                    print("Command output: \(output)")
                }
                // Estimate space based on command output
                let estimatedSpace = result.estimatedSpace
                return CleanupResult(
                    filesDeleted: 1, // Representing one cleanup operation
                    spaceFreed: estimatedSpace,
                    duration: 0.1,
                    errors: []
                )
            } catch {
                return CleanupResult(
                    filesDeleted: 0,
                    spaceFreed: 0,
                    duration: 0,
                    errors: [CleanupError(filePath: scenario.displayName, error: error)]
                )
            }
        } else {
            // For file-based scenarios, scan and delete files
            var allFiles: [FileItem] = []
            let fm = FileManager.default

            for path in result.detectedPaths {
                guard fm.fileExists(atPath: path) else { continue }

                do {
                    let scanner = DiskScanner()
                    let scanResult = try await scanner.scanDirectory(at: path) { _, _ in }
                    let analyzedFiles = riskAnalyzer.analyzeFiles(scanResult.files, rules: rules)
                    allFiles.append(contentsOf: analyzedFiles)
                } catch {
                    continue
                }
            }

            // Filter low-risk files from this scenario
            let scenarioFiles = allFiles.filter { $0.riskLevel == .low }

            return await cleanupFiles(scenarioFiles, rules: rules, progress: progress, confirmAction: nil)
        }
    }
}
