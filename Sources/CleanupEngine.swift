import Foundation

class CleanupEngine {
    private let riskAnalyzer = RiskAnalyzer()
    private let safetyChecker = SafetyChecker()
    private let fileManager = FileManager.default
    private var isCleaning = false
    private var cancellationToken: Bool = false


    // MARK: - Rule Management

    /// Validates rules and returns any conflicts found
    func validateRules(_ rules: CleanupRules) -> (isValid: Bool, conflicts: [RuleConflict]) {
        let conflicts = rules.detectConflicts()
        return (conflicts.isEmpty, conflicts)
    }

    /// Applies rule priority management and resolves conflicts
    func applyRulePriorityManagement(_ rules: inout CleanupRules) {
        // Auto-resolve conflicts before processing
        rules.resolveConflicts()

        // Apply additional priority logic

        // Priority 1: Custom risk overrides take highest precedence
        // Ensure custom overrides are applied before any other rules
        // This is already handled in RiskAnalyzer.classifyRisk()

        // Priority 2: System file protection
        // Ensure system paths are always excluded unless explicitly included
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private", "/Library/Developer"]
        for systemPath in systemPaths {
            if !rules.excludeLocations.contains(where: { $0 == systemPath }) {
                // Add system paths to exclude list if not already present
                rules.excludeLocations.append(systemPath)
            }
        }

        // Priority 3: User home directory protection
        let home = NSHomeDirectory()
        let userProtectedPaths = [
            "\(home)/Documents",
            "\(home)/Desktop",
            "\(home)/Pictures",
            "\(home)/Movies",
            "\(home)/Music"
        ]

        for userPath in userProtectedPaths {
            if !rules.excludeLocations.contains(where: { $0 == userPath }) {
                rules.excludeLocations.append(userPath)
            }
        }

        // Priority 4: Ensure minimum age thresholds are reasonable
        rules.deleteDownloadsOlderThanDays = max(1, rules.deleteDownloadsOlderThanDays)
        rules.deleteLogsOlderThanDays = max(0, rules.deleteLogsOlderThanDays)
        rules.deleteCacheOlderThanDays = max(0, rules.deleteCacheOlderThanDays)

        // Priority 5: Size thresholds validation
        rules.minimumFileSizeToConsider = max(0, rules.minimumFileSizeToConsider)
        rules.skipFilesLargerThan = max(rules.minimumFileSizeToConsider * 10, rules.skipFilesLargerThan)
    }

    /// Dynamically adjusts rules based on file characteristics
    func applyDynamicRules(_ file: FileItem, _ rules: CleanupRules) -> CleanupRules {
        var adjustedRules = rules

        // Dynamic adjustments based on file characteristics
        // 1. Adjust age thresholds for large files
        if file.size > 500 * 1024 * 1024 { // 500 MB
            // Be more conservative with large files
            let currentThreshold = adjustedRules.deleteDownloadsOlderThanDays
            if file.path.contains("/Downloads/") && currentThreshold < 30 {
                adjustedRules.deleteDownloadsOlderThanDays = max(currentThreshold, 30)
            }
        }

        // 2. Adjust for system files
        let path = file.path
        let systemPaths = ["/System", "/usr", "/bin", "/sbin", "/etc", "/private"]
        if systemPaths.contains(where: { path.hasPrefix($0) }) {
            // Always treat system files as high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        }

        // 3. Adjust for application bundles and executables
        if file.path.hasSuffix(".app") || file.path.contains(".app/") || file.path.hasSuffix(".dmg") || file.path.hasSuffix(".pkg") {
            // Application bundles and installers should be high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        }

        // 4. Adjust for very small files (likely temporary/cache)
        if file.size < 1024 * 1024 { // 1 MB
            // Small files can be treated as lower risk if they're in cache/temp locations
            if file.path.contains("/Caches/") || file.path.contains("/tmp/") || file.path.contains("/var/tmp/") {
                if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                    adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                        path: path,
                        riskLevel: .low
                    ))
                }
            }
        }

        // 5. Adjust for file age - very old files in certain locations
        let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0
        if ageInDays > 365 { // Older than 1 year
            if file.path.contains("/Downloads/") || file.path.contains("/Documents/") {
                // Very old user files might be less important
                if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) && rules.getCustomRiskOverride(for: path) == nil {
                    adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                        path: path,
                        riskLevel: .medium
                    ))
                }
            }
        }

        // 6. Adjust for specific file extensions
        let fileExtension = (file.path as NSString).pathExtension.lowercased()
        let highRiskExtensions = ["kext", "component", "plugin", "framework", "bundle"]
        let lowRiskExtensions = ["log", "cache", "tmp", "temp", "db", "db-wal", "db-shm"]

        if highRiskExtensions.contains(fileExtension) {
            // System extensions and plugins are high risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .high
                ))
            }
        } else if lowRiskExtensions.contains(fileExtension) {
            // Cache and log files are lower risk
            if !adjustedRules.customRiskOverrides.contains(where: { $0.path == path }) && rules.getCustomRiskOverride(for: path) == nil {
                adjustedRules.customRiskOverrides.append(CustomRiskOverride(
                    path: path,
                    riskLevel: .low
                ))
            }
        }

        return adjustedRules
    }

    /// Combines multiple rule strategies for better decision making
    func combineRuleStrategies(_ file: FileItem, _ rules: CleanupRules) -> (shouldDelete: Bool, confidence: Double) {
        let assessment = riskAnalyzer.assessRisk(for: file, rules: rules)
        var confidence = 100.0 - assessment.riskScore // Higher confidence for lower risk

        // Apply rule combinations
        var shouldDelete = false
        var combinationCount = 0

        // Combination 1: Age + Location + Risk Level
        if assessment.riskLevel == .low {
            // Low risk files: consider age and location
            let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0

            if file.path.contains("/Caches/") && ageInDays > 7 {
                shouldDelete = true
                confidence = min(confidence + 10.0, 95.0)
                combinationCount += 1
            } else if file.path.contains("/tmp/") && ageInDays > 1 {
                shouldDelete = true
                confidence = min(confidence + 15.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 2: Size + File Type + Custom Override
        let customOverride = rules.getCustomRiskOverride(for: file.path)
        if customOverride == .low && file.size < 10 * 1024 * 1024 { // 10 MB
            shouldDelete = true
            confidence = min(confidence + 20.0, 95.0)
            combinationCount += 1
        }

        // Combination 3: File Extension + Age + Location
        let fileExtension = (file.path as NSString).pathExtension.lowercased()
        let ageInDays = Calendar.current.dateComponents([.day], from: file.modified, to: Date()).day ?? 0

        if ["log", "cache", "tmp", "temp"].contains(fileExtension) && ageInDays > 30 {
            // Old log/cache files in user directories
            if file.path.contains(NSHomeDirectory()) && !file.path.contains("/Library/Application Support/") {
                shouldDelete = true
                confidence = min(confidence + 25.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 4: Large files in download directory with custom risk override
        if file.path.contains("/Downloads/") && file.size > 100 * 1024 * 1024 { // 100 MB
            if let customRisk = rules.getCustomRiskOverride(for: file.path) {
                if customRisk == .medium && ageInDays > 60 {
                    shouldDelete = true
                    confidence = min(confidence + 30.0, 95.0)
                    combinationCount += 1
                }
            } else if ageInDays > 180 { // 6 months old large downloads
                shouldDelete = true
                confidence = min(confidence + 15.0, 95.0)
                combinationCount += 1
            }
        }

        // Combination 5: File in excluded location but with low risk assessment
        let isInExcludedLocation = rules.excludeLocations.contains { file.path.hasPrefix($0) }
        if isInExcludedLocation && assessment.riskLevel == .low && assessment.riskScore < 20 {
            // File is in excluded location but has very low risk score
            // This might indicate a false positive - upgrade to confirm
            shouldDelete = false
            confidence = max(confidence - 10.0, 5.0) // Reduce confidence
            combinationCount += 1
        }

        // Combination 6: App-specific cache files
        if rules.isAppCache(file.path) && ageInDays > 14 {
            // App cache files older than 2 weeks
            shouldDelete = true
            confidence = min(confidence + 35.0, 95.0)
            combinationCount += 1
        }

        // Adjust final confidence based on number of applicable combinations
        if combinationCount > 1 {
            // Multiple combinations agree - increase confidence
            confidence = min(confidence + Double(combinationCount * 5), 95.0)
        } else if combinationCount == 0 {
            // No specific combinations apply - use base confidence but reduce slightly
            confidence = max(confidence - 5.0, 5.0)
        }

        return (shouldDelete, confidence)
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
        applyRulePriorityManagement(&validatedRules)

        // Optional: Log any remaining conflicts for user awareness
        let (_, conflicts) = validateRules(validatedRules)
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
            let dynamicRules = applyDynamicRules(file, validatedRules)
            let (deletionDecision, _) = shouldDeleteFileWithAssessment(file, rules: dynamicRules)

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
                try deleteFile(file)
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

    enum DeletionDecision {
        case skip
        case confirm
        case delete
    }

    /// Enhanced deletion decision using weighted risk assessment
    private func shouldDeleteFileWithAssessment(_ file: FileItem, rules: CleanupRules) -> (decision: DeletionDecision, assessment: RiskAssessment?) {
        // First get the base decision from risk assessment
        let baseDecision = shouldDeleteFileWithRiskAssessment(file, rules: rules)

        // Then apply rule combination strategies for additional insights
        let (shouldDeleteByCombination, confidence) = combineRuleStrategies(file, rules)

        // If rule combination strongly suggests deletion (high confidence) and base decision is skip,
        // upgrade to confirm (let user decide)
        if shouldDeleteByCombination && confidence > 80.0 && baseDecision.decision == .skip {
            return (.confirm, baseDecision.assessment)
        }

        // If rule combination strongly suggests keeping (high confidence against deletion)
        // and base decision is delete, downgrade to confirm
        if !shouldDeleteByCombination && confidence > 80.0 && baseDecision.decision == .delete {
            return (.confirm, baseDecision.assessment)
        }

        return baseDecision
    }

    private func shouldDeleteFileWithRiskAssessment(_ file: FileItem, rules: CleanupRules) -> (decision: DeletionDecision, assessment: RiskAssessment?) {
        // Perform comprehensive risk assessment
        let assessment = riskAnalyzer.assessRisk(for: file, rules: rules)

        // Apply rules based on risk assessment
        switch assessment.riskLevel {
        case .high:
            if rules.neverDeleteHighRisk {
                return (.skip, assessment)
            }
            // Even if not "never delete", require confirmation for high risk
            return (.confirm, assessment)

        case .medium:
            if rules.confirmMediumRisk {
                return (.confirm, assessment)
            }
            // For medium risk files with low score, consider deletion
            if assessment.riskScore < 40 {
                return (.delete, assessment)
            }
            return (.skip, assessment)

        case .low:
            if rules.autoCleanLowRisk {
                // For low risk files with very low score, auto-delete
                if assessment.riskScore < 20 {
                    return (.delete, assessment)
                }
                // Otherwise confirm for low risk files with moderate score
                return (.confirm, assessment)
            }
            return (.skip, assessment)
        }
    }

    private func shouldDeleteFile(_ file: FileItem, rules: CleanupRules) -> DeletionDecision {
        // Check risk level rules
        switch file.riskLevel {
        case .high:
            return rules.neverDeleteHighRisk ? .skip : .confirm
        case .medium:
            return rules.confirmMediumRisk ? .confirm : .skip
        case .low:
            return rules.autoCleanLowRisk ? .delete : .skip
        }
    }

    private func deleteFile(_ file: FileItem) throws {
        let url = file.url

        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        // Try to move to trash first (safer)
        if #available(macOS 10.8, *) {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
            print("Moved to trash: \(url.path)")
        } else {
            // Fallback: permanent delete
            try fileManager.removeItem(at: url)
            print("Permanently deleted: \(url.path)")
        }
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

    func quickCleanup(rules: CleanupRules, progress: @escaping (Int, Int, Int64) -> Void, confirmAction: ((FileItem) async -> Bool)? = nil) async -> CleanupResult {
        // Apply rule validation and priority management before processing
        var validatedRules = rules
        applyRulePriorityManagement(&validatedRules)

        // Identify common cache locations
        let cachePaths = [
            NSHomeDirectory() + "/Library/Caches",
            "/Library/Caches",
            "/var/tmp",
            "/tmp"
        ]

        var allFiles: [FileItem] = []

        for path in cachePaths {
            guard fileManager.fileExists(atPath: path) else {
                continue
            }

            let scanner = DiskScanner()
            do {
                let result = try await scanner.scanDirectory(at: path) { _, _ in }
                let analyzer = RiskAnalyzer()
                let analyzedFiles = analyzer.analyzeFiles(result.files, rules: validatedRules)
                allFiles.append(contentsOf: analyzedFiles)
            } catch {
                print("Error scanning \(path): \(error)")
            }
        }

        // Filter for low-risk files only
        let lowRiskFiles = allFiles.filter { $0.riskLevel == .low }

        return await cleanupFiles(lowRiskFiles, rules: validatedRules, progress: progress, confirmAction: confirmAction)
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
        print("Estimated cleanup space: \(formatBytes(estimatedSpace))")

        // Step 3: Scan for files using rules
        let scanner = DiskScanner()
        var allFiles: [FileItem] = []

        for includePath in rules.includeLocations {
            guard fileManager.fileExists(atPath: includePath) else { continue }

            do {
                let scanResult = try await scanner.scanDirectory(at: includePath) { scanned, total in
                    progress(0, 1, 0) // Update progress during scan
                }
                let analyzer = RiskAnalyzer()
                let analyzedFiles = analyzer.analyzeFiles(scanResult.files, rules: rules)
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
                description: "Insufficient disk space for estimated cleanup size (\(formatBytes(estimatedSize)))",
                path: nil,
                severity: .high
            ))
        }

        return SafetyCheckResult(isSafe: issues.isEmpty, safetyIssues: issues)
    }

    /// Estimate cleanup space based on rules and scenarios
    func estimateCleanupSpace(rules: CleanupRules) -> Int64 {
        let estimator = SpaceEstimator()

        // Estimate space based on scenarios if preset is active
        if let activePreset = rules.activePreset {
            let presetManager = CleanupPresetManager()
            let report = presetManager.getPresetSavingsReport(activePreset)
            return report.totalSavings
        }

        // Estimate space based on rules
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
                let output = try executeCommand(command)
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
            let scanner = DiskScanner()

            for path in result.detectedPaths {
                guard fileManager.fileExists(atPath: path) else { continue }

                do {
                    let scanResult = try await scanner.scanDirectory(at: path) { _, _ in }
                    let analyzer = RiskAnalyzer()
                    let analyzedFiles = analyzer.analyzeFiles(scanResult.files, rules: rules)
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

    // MARK: - Helper Methods

    private func executeCommand(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}